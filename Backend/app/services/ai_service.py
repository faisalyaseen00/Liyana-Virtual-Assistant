from app.models.message import Message
from app.providers.base import LLMMessage, LLMProvider


class AIService:
    def __init__(self, provider: LLMProvider):
        self.provider = provider

    async def generate_response(
        self,
        history: list[Message],
    ) -> str:

        messages: list[LLMMessage] = [
            LLMMessage(
                role=message.role.value,
                content=message.content,
            )
            for message in history
        ]

        return await self.provider.generate(messages)