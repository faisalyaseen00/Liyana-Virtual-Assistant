import asyncio
import base64
import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest

from app.core.settings import settings
from app.models.message import Message
from app.models.task import Task
from app.repositories.session_repository import SessionRepository
from app.repositories.user_repository import UserRepository
from app.services import live_voice
from app.utils.jwt import create_access_token


class FakeGemini:
    """Stands in for the Gemini Live socket: records what we send and
    replays scripted server messages."""

    def __init__(self, script: list[dict]):
        self.sent: list[dict] = []
        self.inbox: asyncio.Queue = asyncio.Queue()
        self.script = list(script)
        self.closed = False

    async def send(self, message: str) -> None:
        data = json.loads(message)
        self.sent.append(data)
        if "setup" in data:
            await self.inbox.put({"setupComplete": {}})
        elif self.script and ("realtimeInput" in data or "toolResponse" in data):
            # Each thing we send releases the next scripted batch.
            for item in self.script.pop(0):
                await self.inbox.put(item)

    async def recv(self) -> str:
        item = await self.inbox.get()
        if item is None:
            raise ConnectionError("closed")
        return json.dumps(item)

    async def close(self) -> None:
        self.closed = True
        await self.inbox.put(None)


def make_user(db):
    user = UserRepository.create(
        db,
        email=f"live-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )
    user.timezone = "UTC"
    db.commit()
    return user


AUDIO = base64.b64encode(b"\x01\x02\x03\x04").decode()


def task_script():
    return [
        # After the user's audio: what Gemini heard, then a tool call.
        [
            {"serverContent": {"inputTranscription": {"text": "add task "}}},
            {"serverContent": {"inputTranscription": {"text": "buy milk tomorrow"}}},
            {
                "toolCall": {
                    "functionCalls": [
                        {
                            "id": "call-1",
                            "name": "create_task",
                            "args": {"title": "Buy milk", "due_date": "2030-01-10"},
                        }
                    ]
                }
            },
        ],
        # After our tool response: Liyana speaks and the turn ends.
        [
            {
                "serverContent": {
                    "outputTranscription": {"text": "Done, "},
                    "modelTurn": {"parts": [{"inlineData": {"data": AUDIO}}]},
                }
            },
            {"serverContent": {"outputTranscription": {"text": "added Buy milk."}}},
            {"serverContent": {"turnComplete": True}},
        ],
    ]


@pytest.mark.asyncio
async def test_session_runs_tool_streams_audio_and_saves_turn(db_session):
    user = make_user(db_session)
    gemini = FakeGemini(task_script())
    events: list[dict] = []
    audio: list[bytes] = []

    async def send_json(message):
        events.append(message)

    async def send_bytes(data):
        audio.append(data)

    session = live_voice.LiveVoiceSession(
        db=db_session,
        user=user,
        gemini=gemini,
        send_json=send_json,
        send_bytes=send_bytes,
    )
    await session.start()
    pump = asyncio.create_task(session.pump_from_gemini())
    await session.send_audio(b"\x00\x00" * 160)

    for _ in range(100):
        if any(e["type"] == "turn_complete" for e in events):
            break
        await asyncio.sleep(0.01)
    pump.cancel()

    setup = gemini.sent[0]["setup"]
    assert setup["model"] == f"models/{settings.gemini_live_model}"
    names = [d["name"] for d in setup["tools"][0]["functionDeclarations"]]
    assert "create_task" in names and "create_reminder" in names

    sent_audio = gemini.sent[1]["realtimeInput"]["audio"]
    assert sent_audio["mimeType"] == "audio/pcm;rate=16000"

    # The tool really ran and Gemini got the result plus a spoken summary.
    task = db_session.query(Task).one()
    assert task.title == "Buy milk" and task.user_id == user.id
    response = gemini.sent[2]["toolResponse"]["functionResponses"][0]
    assert response["id"] == "call-1"
    assert response["response"]["summary"].startswith('Done! I\'ve added the task "Buy milk"')

    assert audio == [b"\x01\x02\x03\x04"]
    assert events[0] == {"type": "ready", "conversation_id": None}
    assert {"type": "tool", "name": "create_task"}.items() <= next(
        e for e in events if e["type"] == "tool"
    ).items()

    # The turn is in chat history, tagged so the app refreshes tasks.
    saved = db_session.query(Message).order_by(Message.created_at).all()
    assert [m.content for m in saved] == ["add task buy milk tomorrow", "Done, added Buy milk."]
    assert saved[1].extra_data["tool"] == "create_task"
    assert saved[1].extra_data["source"] == "live"
    done = next(e for e in events if e["type"] == "turn_complete")
    assert done["conversation_id"] == str(saved[0].conversation_id)


@pytest.mark.asyncio
async def test_tool_errors_go_back_to_gemini_not_the_user(db_session):
    user = make_user(db_session)
    gemini = FakeGemini([])
    session = live_voice.LiveVoiceSession(
        db=db_session,
        user=user,
        gemini=gemini,
        send_json=lambda m: asyncio.sleep(0),
        send_bytes=lambda b: asyncio.sleep(0),
    )

    await session.handle(
        {
            "toolCall": {
                "functionCalls": [
                    {"id": "x", "name": "create_reminder", "args": {"title": "Call"}}
                ]
            }
        }
    )

    response = gemini.sent[-1]["toolResponse"]["functionResponses"][0]
    assert "error" in response["response"]


@pytest.mark.asyncio
async def test_interruption_is_forwarded(db_session):
    events = []

    async def send_json(message):
        events.append(message)

    session = live_voice.LiveVoiceSession(
        db=db_session,
        user=make_user(db_session),
        gemini=FakeGemini([]),
        send_json=send_json,
        send_bytes=lambda b: asyncio.sleep(0),
    )
    await session.handle({"serverContent": {"interrupted": True}})

    assert events == [{"type": "interrupted"}]


def _login(db, user):
    session = SessionRepository(db).create(
        user_id=user.id,
        refresh_token_hash=uuid4().hex,
        expires_at=datetime.now(timezone.utc) + timedelta(days=1),
    )
    return create_access_token(user_id=user.id, session_id=session.id)


def test_websocket_rejects_bad_token(client):
    with client.websocket_connect("/api/v1/live") as ws:
        ws.send_text(json.dumps({"type": "auth", "token": "nope"}))
        message = ws.receive()
    assert message["type"] == "websocket.close"
    assert message["code"] == 4401


def test_websocket_relays_a_conversation(client, db_session, monkeypatch):
    user = make_user(db_session)
    gemini = FakeGemini(task_script())

    async def fake_connect():
        return gemini

    monkeypatch.setattr(settings, "gemini_api_key", "test-key")
    monkeypatch.setattr(live_voice, "open_gemini_connection", fake_connect)

    with client.websocket_connect("/api/v1/live") as ws:
        ws.send_text(json.dumps({"type": "auth", "token": _login(db_session, user)}))
        assert ws.receive_json()["type"] == "ready"

        ws.send_bytes(b"\x00\x00" * 160)
        seen = []
        while not seen or seen[-1].get("type") != "turn_complete":
            message = ws.receive()
            if message.get("bytes"):
                seen.append({"type": "audio"})
            else:
                seen.append(json.loads(message["text"]))

        ws.send_text(json.dumps({"type": "end"}))

    kinds = [m["type"] for m in seen]
    assert "tool" in kinds and "audio" in kinds and kinds[-1] == "turn_complete"
    assert db_session.query(Task).one().title == "Buy milk"
