from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.registery import tool_registry
from app.providers.base import LLMMessage


SYSTEM_PROMPT = """You are Liyana's Semantic Router.

Classify the user's request into exactly one route:

- `tool` — select an available tool/action and its arguments.
- `conversation` — answer, explain, discuss, or chat.
- `clarification` — required information is missing.

Rules:
- Use only provided tools; never invent or execute them.
- Use relevant context.
- If required information cannot be inferred, return `clarification`.
- Return only valid JSON matching the required schema.
"""


class SemanticRouter:
    def __init__(self, provider):
        self.provider = provider

    async def route(
        self,
        user_input: str,
        context: str = "",
    ) -> RouterResponse:

        tools = tool_registry.list_tools()

        tool_info = "\n".join(
            f"- {tool.name}: {tool.description} "
            f"Parameters: {tool.parameters}"
            for tool in tools
        )

        user_prompt = f"""Available tools:
{tool_info}

Context:
{context}

User request:
{user_input}
"""

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
            ]
        )

        return RouterResponse.model_validate_json(response)