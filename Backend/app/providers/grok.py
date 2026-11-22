from groq import AsyncGroq

from app.core.settings import settings
from app.providers.base import LLMMessage, LLMProvider


class GrokProvider(LLMProvider):
    def __init__(self):
        self.client = AsyncGroq(
            api_key=settings.groq_api_key,
        )

    async def generate(self, messages: list[LLMMessage]) -> str:
        options: dict = {}

        # Reasoning models (e.g. openai/gpt-oss-*) spend completion tokens on
        # hidden reasoning before answering. With a small token budget the
        # reasoning can use it all and the answer comes back empty, so keep
        # the reasoning short.
        if settings.groq_model.startswith("openai/gpt-oss"):
            options["reasoning_effort"] = "low"

        response = await self.client.chat.completions.create(
            model=settings.groq_model,
            messages=[
                {
                    "role": message.role,
                    "content": message.content,
                }
                for message in messages
            ],
            max_completion_tokens=settings.groq_max_completion_tokens,
            **options,
        )

        return (response.choices[0].message.content or "").strip()
