from groq import AsyncGroq

from app.core.settings import settings
from app.services.ai_service import LLMProvider
from app.services.ai_service import LLMMessage


class GrokProvider(LLMProvider):
    def __init__(self):
        self.client = AsyncGroq(
            api_key=settings.groq_api_key
        )

    async def generate(self, messages: list[LLMMessage]) -> str:
        response = await self.client.chat.completions.create(
            model=settings.groq_model,
            messages=[
                {
                    "role": message.role,
                    "content": message.content,
                }
                for message in messages
            ],
            max_completion_tokens=300,
        )

        return response.choices[0].message.content or ""