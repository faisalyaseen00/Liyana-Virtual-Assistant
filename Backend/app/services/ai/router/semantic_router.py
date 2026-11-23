from pydantic import ValidationError

from app.services.ai.router.schemas import RouterResponse
from app.services.ai.router.validator import validate_router_response
from app.services.ai.tools.registery import tool_registry
from app.utils.dates import today_label
from app.providers.base import LLMMessage


SYSTEM_PROMPT = """You are Liyana's Semantic Router.

Classify the user's request into exactly one route:

- `tool` — select an available tool/action and its arguments.
- `conversation` — answer, explain, discuss, or chat.
- `clarification` — required information is missing.

Rules:
- Use only provided tools; never invent or execute them.
- Use relevant context.
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

    async def route(
        self,
        user_input: str,
        context: str = "",
        tz: str | None = None,
    ) -> RouterResponse:

        tools = tool_registry.list_tools()

        tool_info = "\n".join(
            f"- {tool.name}: {tool.description} "
            f"Parameters: {tool.parameters}"
            for tool in tools
        )

        today = today_label(tz)

        user_prompt = f"""Today's date: {today}

Available tools:
{tool_info}

Context:
{context}

User request:
{user_input}
"""

        options = (
            {"json_mode": True}
            if getattr(self.provider, "supports_json_mode", False)
            else {}
        )

        response = await self.provider.generate(
            [
                LLMMessage(
                    role="system",
                    content=SYSTEM_PROMPT,
                ),
                LLMMessage(
                    role="user",
                    content=user_prompt,
                ),
            ],
            **options,
        )

        return parse_router_output(response)
