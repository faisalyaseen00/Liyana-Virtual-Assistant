from app.models.message import Message
from app.providers.base import LLMMessage, LLMProvider


class AIService:
    def __init__(self, provider: LLMProvider):
        self.provider = provider

    async def generate_response(
        self,
        history: list[Message],
        pending_user_message: str | None = None,
    ) -> str:

        messages: list[LLMMessage] = [
            LLMMessage(
                role=message.role.value,
                content=message.content,
            )
            for message in history
        ]

        if pending_user_message is not None:
            messages.append(
                LLMMessage(
                    role="user",
                    content=pending_user_message,
                )
            )

        return await self.provider.generate(messages)