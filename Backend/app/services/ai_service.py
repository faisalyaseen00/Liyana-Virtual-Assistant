from app.models.message import Message
from app.utils.dates import today_label
from app.providers.base import LLMMessage, LLMProvider

ASSISTANT_PROMPT = """You are Liyana, a friendly and helpful personal virtual assistant.
Answer clearly and concisely. Today's date is {today}."""

EMPTY_REPLY_FALLBACK = "Sorry, I couldn't come up with a reply. Could you try again?"


class AIService:
    def __init__(self, provider: LLMProvider):
        self.provider = provider

    async def generate_response(
        self,
        history: list[Message],
        pending_user_message: str | None = None,
        tz: str | None = None,
    ) -> str:

        today = today_label(tz)

        messages: list[LLMMessage] = [
            LLMMessage(
                role="system",
                content=ASSISTANT_PROMPT.format(today=today),
            )
        ]

        messages.extend(
            LLMMessage(
                role=message.role.value,
                content=message.content,
            )
            for message in history
        )

        if pending_user_message is not None:
            messages.append(
                LLMMessage(
                    role="user",
                    content=pending_user_message,
                )
            )

        reply = await self.provider.generate(messages)

        # Never store an empty assistant message.
        return reply.strip() or EMPTY_REPLY_FALLBACK
