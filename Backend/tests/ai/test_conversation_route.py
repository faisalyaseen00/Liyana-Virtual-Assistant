from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.models.enums import MessageRole
from app.providers.base import LLMMessage, LLMProvider
from app.services.chat_service import ChatService


class ConversationProvider(LLMProvider):
    def __init__(self):
        self.calls: list[list[LLMMessage]] = []

    async def generate(self, messages: list[LLMMessage]) -> str:
        self.calls.append(messages)

        if "Semantic Router" in messages[0].content:
            return '{"route":"conversation"}'

        return "Here is the conversational answer."


class MessageServiceStub:
    def __init__(self):
        self.history = [
            SimpleNamespace(
                role=MessageRole.USER,
                content="Earlier context",
            )
        ]
        self.created: list[dict] = []

    def get_recent_messages(self, **kwargs):
        return self.history

    def create_message(self, **kwargs):
        self.created.append(kwargs)
        return SimpleNamespace(**kwargs)


@pytest.mark.asyncio
async def test_conversation_route_reaches_conversational_llm():
    provider = ConversationProvider()
    message_service = MessageServiceStub()
    service = ChatService(db=None, provider=provider)
    service.message_service = message_service

    result = await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="Explain this topic",
    )

    assert result[1].content == "Here is the conversational answer."
    assert len(provider.calls) == 2
    assert provider.calls[1][-2].content == "Earlier context"
    assert provider.calls[1][-1].content == "Explain this topic"
    assert [item["role"] for item in message_service.created] == [
        MessageRole.USER,
        MessageRole.ASSISTANT,
    ]
