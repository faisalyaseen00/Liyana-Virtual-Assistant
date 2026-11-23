"""Real-time voice conversations with Liyana over Gemini Live.

The phone streams microphone audio to our WebSocket; this module relays it
to Gemini Live and streams Liyana's spoken reply back. The Gemini key never
leaves the server. When Gemini wants to act (create a task, set a
reminder...) it calls the same tools as text chat, run here for the
signed-in user, and every finished turn is saved to chat history.

Phone <-> server protocol
  phone -> server   binary: 16 kHz mono 16-bit PCM microphone audio
                    text:   {"type": "text", "text": "..."} typed input
                            {"type": "end"} hang up
  server -> phone   binary: 24 kHz mono 16-bit PCM audio of Liyana speaking
                    text:   {"type": "ready", "conversation_id": null}
                            {"type": "transcript", "role": "user" | "assistant",
                             "text": "...", "final": false}
                            {"type": "tool", "name": "...", "result": {...}}
                            {"type": "interrupted"}  stop playing audio now
                            {"type": "turn_complete", "conversation_id": "..."}
                            {"type": "error", "message": "..."}
"""

import asyncio
import base64
import contextlib
import json
import logging
from collections.abc import Awaitable, Callable
from typing import Any, Protocol
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.settings import settings
from app.models.enums import MessageRole
from app.models.user import User
from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.executor import ToolExecutor
from app.services.ai.tools.registery import tool_registry
from app.services.chat_service import ChatService
from app.services.conversation_service import ConversationService
from app.services.message_service import MessageService
from app.utils import dates

logger = logging.getLogger(__name__)

GEMINI_LIVE_URL = (
    "wss://generativelanguage.googleapis.com/ws/"
    "google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
)
INPUT_MIME = "audio/pcm;rate=16000"

LIVE_PROMPT = """You are Liyana, a warm, smart personal virtual assistant, \
talking with {name} by voice in real time.

Right now it is {now} ({tz}).

How to talk:
- This is a spoken conversation: keep replies short and natural (one to
  three sentences), no lists, no markdown, no emojis.
- Reply in the language the user speaks: English, Urdu or Roman Urdu.
- The user may mix English and Urdu ("kal" = tomorrow, "parson" = day
  after tomorrow, "subah" = morning, "shaam" = evening, "raat" = night).

What you can do (use the tools, never pretend):
- Create tasks with create_task. Reminders are set automatically from the
  deadline, so don't also call create_reminder; afterwards tell the user
  when you'll remind them, using the tool's "summary".
- Set reminders with create_reminder. A reminder needs a time; if none was
  given, ask "What time should I remind you?" first.
- List open tasks with get_tasks and upcoming reminders with
  list_reminders, then summarise them briefly out loud.
- Tool dates are YYYY-MM-DD and times HH:MM (24-hour), worked out from the
  current date and time above ("Friday" = the coming Friday, "evening" =
  18:00, "in 2 hours" = now + 2 hours).
- If a tool returns an error, ask one short question to fix it.
- Only ask for details that are truly missing; otherwise just do it.
"""


class GeminiConnection(Protocol):
    async def send(self, message: str) -> None: ...

    async def recv(self) -> str | bytes: ...

    async def close(self) -> None: ...


async def open_gemini_connection() -> GeminiConnection:
    """Connect to Gemini Live. Tests replace this function."""
    import websockets

    return await websockets.connect(
        GEMINI_LIVE_URL,
        additional_headers={"x-goog-api-key": settings.gemini_api_key or ""},
        max_size=None,
        open_timeout=10,
    )


def _schema_type(spec: dict[str, Any]) -> str:
    kind = spec.get("type", "string")
    return {"str": "string", "int": "integer", "bool": "boolean"}.get(kind, kind)


def tool_declarations() -> list[dict[str, Any]]:
    """Our chat tools in Gemini's function-calling format."""
    declarations = []
    for tool in tool_registry.list_tools():
        properties: dict[str, Any] = {}
        required: list[str] = []
        for name, spec in tool.parameters.items():
            prop: dict[str, Any] = {"type": _schema_type(spec)}
            notes = [
                spec.get("description"),
                f"Format: {spec['format']}" if spec.get("format") else None,
            ]
            description = ". ".join(n for n in notes if n)
            if description:
                prop["description"] = description
            if spec.get("enum"):
                prop["enum"] = spec["enum"]
            properties[name] = prop
            if spec.get("required"):
                required.append(name)

        declaration: dict[str, Any] = {
            "name": tool.name,
            "description": tool.description,
        }
        if properties:
            declaration["parameters"] = {
                "type": "object",
                "properties": properties,
                "required": required,
            }
        declarations.append(declaration)
    return declarations


def setup_message(user: User) -> dict[str, Any]:
    tz = user.timezone if dates.is_valid_timezone(user.timezone or "") else None
    now = dates._now(tz)
    prompt = LIVE_PROMPT.format(
        name=user.full_name or "the user",
        now=now.strftime("%A, %Y-%m-%d %H:%M"),
        tz=tz or "server time",
    )
    return {
        "setup": {
            "model": f"models/{settings.gemini_live_model}",
            "generationConfig": {
                "responseModalities": ["AUDIO"],
                "speechConfig": {
                    "voiceConfig": {
                        "prebuiltVoiceConfig": {
                            "voiceName": settings.gemini_live_voice,
                        }
                    }
                },
            },
            "systemInstruction": {"parts": [{"text": prompt}]},
            "tools": [{"functionDeclarations": tool_declarations()}],
            "inputAudioTranscription": {},
            "outputAudioTranscription": {},
            # Lets a long conversation keep going past the context limit.
            "contextWindowCompression": {"slidingWindow": {}},
        }
    }


SendJson = Callable[[dict[str, Any]], Awaitable[None]]
SendBytes = Callable[[bytes], Awaitable[None]]


class LiveVoiceSession:
    """One live call: relays audio both ways, runs tools, saves turns."""

    def __init__(
        self,
        *,
        db: Session,
        user: User,
        gemini: GeminiConnection,
        send_json: SendJson,
        send_bytes: SendBytes,
        tool_executor: ToolExecutor | None = None,
    ):
        self.db = db
        self.user = user
        self.gemini = gemini
        self.send_json = send_json
        self.send_bytes = send_bytes
        self.tz = user.timezone if dates.is_valid_timezone(user.timezone or "") else None
        self.tools = tool_executor or ToolExecutor.for_user(db, user.id, self.tz)
        self.conversation_id: UUID | None = None

        # What was said in the current turn, saved when the turn completes.
        self._user_text: list[str] = []
        self._assistant_text: list[str] = []
        self._turn_tools: list[dict[str, Any]] = []

    async def start(self) -> None:
        await self.gemini.send(json.dumps(setup_message(self.user)))
        while True:
            reply = _decode(await self.gemini.recv())
            if "setupComplete" in reply:
                break
        await self.send_json({"type": "ready", "conversation_id": None})

    # ---------- phone -> Gemini ----------

    async def send_audio(self, pcm: bytes) -> None:
        await self.gemini.send(
            json.dumps(
                {
                    "realtimeInput": {
                        "audio": {
                            "data": base64.b64encode(pcm).decode(),
                            "mimeType": INPUT_MIME,
                        }
                    }
                }
            )
        )

    async def send_text(self, text: str) -> None:
        text = text.strip()
        if not text:
            return
        self._user_text.append(text)
        await self.gemini.send(json.dumps({"realtimeInput": {"text": text}}))

    # ---------- Gemini -> phone ----------

    async def pump_from_gemini(self) -> None:
        """Forward everything Gemini sends until it hangs up."""
        while True:
            try:
                raw = await self.gemini.recv()
            except Exception:  # noqa: BLE001 - Gemini closed the socket
                return
            await self.handle(_decode(raw))

    async def handle(self, message: dict[str, Any]) -> None:
        if "toolCall" in message:
            await self._run_tools(message["toolCall"].get("functionCalls") or [])
            return

        if "goAway" in message:
            await self.send_json(
                {"type": "error", "message": "The voice session is ending soon."}
            )
            return

        content = message.get("serverContent")
        if not content:
            return

        heard = (content.get("inputTranscription") or {}).get("text")
        if heard:
            self._user_text.append(heard)
            await self.send_json(
                {"type": "transcript", "role": "user", "text": heard, "final": False}
            )

        said = (content.get("outputTranscription") or {}).get("text")
        if said:
            self._assistant_text.append(said)
            await self.send_json(
                {"type": "transcript", "role": "assistant", "text": said, "final": False}
            )

        for part in (content.get("modelTurn") or {}).get("parts") or []:
            data = (part.get("inlineData") or {}).get("data")
            if data:
                await self.send_bytes(base64.b64decode(data))

        if content.get("interrupted"):
            await self.send_json({"type": "interrupted"})

        if content.get("turnComplete"):
            self._save_turn()
            await self.send_json(
                {
                    "type": "turn_complete",
                    "conversation_id": (
                        str(self.conversation_id) if self.conversation_id else None
                    ),
                }
            )

    async def _run_tools(self, calls: list[dict[str, Any]]) -> None:
        responses = []
        for call in calls:
            name = call.get("name") or ""
            args = call.get("args") or {}
            try:
                result = await self.tools.execute(
                    RouterResponse(route="tool", tool=name, arguments=args)
                )
                payload = {
                    "result": result,
                    "summary": ChatService._describe_tool_result(name, result, self.tz),
                }
                self._turn_tools.append({"tool": name, "arguments": args, "result": result})
                await self.send_json({"type": "tool", "name": name, "result": result})
            except (TypeError, ValueError) as error:
                payload = {"error": str(error) or "Invalid arguments"}

            responses.append({"id": call.get("id"), "name": name, "response": payload})

        await self.gemini.send(
            json.dumps({"toolResponse": {"functionResponses": responses}})
        )

    def _save_turn(self) -> None:
        user_text = _join(self._user_text)
        assistant_text = _join(self._assistant_text)
        tools = self._turn_tools
        self._user_text, self._assistant_text, self._turn_tools = [], [], []

        if not user_text and not assistant_text:
            return

        try:
            messages = MessageService(self.db)
            if self.conversation_id is None:
                conversations = ConversationService(self.db)
                conversation = conversations.create_conversation(user_id=self.user.id)
                self.conversation_id = conversation.id
                if user_text:
                    conversations.set_title_from_first_message(
                        conversation_id=conversation.id,
                        user_id=self.user.id,
                        content=user_text,
                    )

            if user_text:
                messages.create_message(
                    conversation_id=self.conversation_id,
                    user_id=self.user.id,
                    role=MessageRole.USER,
                    content=user_text,
                    extra_data={"source": "live"},
                )
            if assistant_text:
                extra: dict[str, Any] = {"source": "live"}
                if tools:
                    # Same shape as text chat, so the app refreshes the tab.
                    extra.update(route="tool", **tools[-1], tools=tools)
                messages.create_message(
                    conversation_id=self.conversation_id,
                    user_id=self.user.id,
                    role=MessageRole.ASSISTANT,
                    content=assistant_text,
                    extra_data=extra,
                )
        except Exception:
            logger.exception("Could not save live voice turn")
            self.db.rollback()


def _decode(raw: str | bytes) -> dict[str, Any]:
    if isinstance(raw, bytes):
        raw = raw.decode("utf-8")
    try:
        value = json.loads(raw)
    except ValueError:
        return {}
    return value if isinstance(value, dict) else {}


def _join(pieces: list[str]) -> str:
    """Transcription arrives in fragments; glue them into one tidy line."""
    text = "".join(pieces)
    return " ".join(text.split())


async def run_session(session: LiveVoiceSession, receive: Callable[[], Awaitable[dict]]) -> None:
    """Relay until either side hangs up."""
    pump = asyncio.create_task(session.pump_from_gemini())
    try:
        while not pump.done():
            receive_task = asyncio.create_task(receive())
            done, _ = await asyncio.wait(
                {receive_task, pump}, return_when=asyncio.FIRST_COMPLETED
            )
            if receive_task not in done:
                receive_task.cancel()
                break

            message = receive_task.result()
            if message.get("type") == "websocket.disconnect":
                break
            if message.get("bytes"):
                await session.send_audio(message["bytes"])
                continue

            data = _decode(message.get("text") or "")
            if data.get("type") == "end":
                break
            if data.get("type") == "text":
                await session.send_text(str(data.get("text") or ""))
    finally:
        pump.cancel()
        with contextlib.suppress(Exception):
            await session.gemini.close()
