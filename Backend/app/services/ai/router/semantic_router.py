from pydantic import ValidationError

from app.providers.base import LLMMessage
from app.services.ai.router.schemas import RouterResponse
from app.services.ai.router.validator import validate_router_response
from app.services.ai.tools.registery import tool_registry
from app.utils.dates import today_label

SYSTEM_PROMPT = """You are Liyana's Semantic Router.

Classify the user's request into exactly one route:

- `tool` — select an available tool/action and its arguments.
- `conversation` — answer, explain, discuss, or chat.
- `clarification` — required information is missing.

Understanding the user:
- Requests are often spoken and transcribed, so expect typos, missing
  punctuation, filler words, wrong homophones ("to/two", "for/four") and
  English mixed with Urdu or Roman Urdu ("kal" = tomorrow, "parson" = day
  after tomorrow, "subah" = morning, "shaam" = evening, "raat" = night).
  Work out what they most likely mean, the way a smart human assistant would.
- Use the recent conversation: a short reply like "Friday" or "at 5" usually
  answers the question you asked last.
- Turn relative dates and times into exact values using today's date:
  "Friday" = the coming Friday, "next week" = Monday of next week,
  "morning" = 09:00, "afternoon" = 14:00, "evening" = 18:00,
  "night" = 21:00, "in 2 hours" = now + 2 hours.
- A reminder needs a time. If the user gave a subject but no time (and no
  word like "morning" or "evening"), return `clarification` asking only
  "What time should I remind you?". Don't create it without a time.
- Prefer acting over asking. Only return `clarification` when something
  required truly cannot be inferred (e.g. "remind me" with no subject), and
  then ask one short, specific question.

Rules:
- Use only provided tools; never invent or execute them.
- Dates are YYYY-MM-DD and times are HH:MM (24-hour) in tool arguments.
- Reply in the user's language and style (English, Urdu or Roman Urdu).
- If required information cannot be inferred, return `clarification`
  and put the question to ask the user in `message`.
- For `conversation`, you are Liyana, a friendly and helpful personal
  virtual assistant: put your full, clear, concise reply to the user in
  `message`.
- Return only a single JSON object, with no extra text or code fences,
  in this shape:
  {"route": "tool" | "conversation" | "clarification",
   "tool": "<tool name or null>",
   "arguments": {},
   "message": "<reply, clarification question, or null>"}
"""


def parse_router_output(raw: str) -> RouterResponse:
    """Parse the model's reply, falling back to `conversation` when the
    reply is not a usable routing decision."""
    text = raw.strip()

    # Models often wrap JSON in prose or ``` fences; keep only the object.
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end > start:
        text = text[start : end + 1]

    try:
        response = RouterResponse.model_validate_json(text)
        return validate_router_response(response)
    except (ValidationError, ValueError):
        return RouterResponse(route="conversation")


class SemanticRouter:
    def __init__(self, provider):
        self.provider = provider

    @staticmethod
    def _prompt(user_input: str, context: str, tz: str | None) -> str:
        tool_info = "\n".join(
            f"- {tool.name}: {tool.description} "
            f"Parameters: {tool.parameters}"
            for tool in tool_registry.list_tools()
        )

        return f"""Today: {today_label(tz)}

Available tools:
{tool_info}

Context:
{context}

User request:
{user_input}
"""

    async def _ask(self, messages: list[LLMMessage]) -> RouterResponse:
        options = (
            {"json_mode": True}
            if getattr(self.provider, "supports_json_mode", False)
            else {}
        )
        response = await self.provider.generate(messages, **options)
        return parse_router_output(response)

    async def route(
        self,
        user_input: str,
        context: str = "",
        tz: str | None = None,
    ) -> RouterResponse:
        return await self._ask(
            [
                LLMMessage(role="system", content=SYSTEM_PROMPT),
                LLMMessage(
                    role="user",
                    content=self._prompt(user_input, context, tz),
                ),
            ]
        )

    async def repair(
        self,
        user_input: str,
        failed: RouterResponse,
        error: str,
        context: str = "",
        tz: str | None = None,
    ) -> RouterResponse:
        """Second look after a tool rejected the model's arguments: let the
        model correct its own reading of the request, or ask the user one
        precise question about what is really missing."""
        return await self._ask(
            [
                LLMMessage(role="system", content=SYSTEM_PROMPT),
                LLMMessage(
                    role="user",
                    content=self._prompt(user_input, context, tz),
                ),
                LLMMessage(
                    role="assistant",
                    content=failed.model_dump_json(),
                ),
                LLMMessage(
                    role="user",
                    content=(
                        f"That could not be done: {error}\n"
                        "Re-read the request and context. If you can work out "
                        "the correct arguments, return the fixed tool call. "
                        "If something required is genuinely unknown, return "
                        "`clarification` with one short, specific question "
                        "for the user about just that."
                    ),
                ),
            ]
        )
