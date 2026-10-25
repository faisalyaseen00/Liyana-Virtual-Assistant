from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.models.enums import MessageRole
from app.providers.base import LLMMessage, LLMProvider
from app.services.chat_service import ChatService


class ClarificationProvider(LLMProvider):
    def __init__(self):
        self.calls = 0

    async def generate(self, messages: list[LLMMessage]) -> str:
        self.calls += 1
        if self.calls > 1:
            raise AssertionError("The conversational LLM must not be called")

        return '{"route":"clarification","message":"What should I remind you about?"}'


class MessageServiceStub:
    def __init__(self):
        self.created = []

    def get_recent_messages(self, **kwargs):
        return []

    def create_message(self, **kwargs):
        self.created.append(kwargs)
        return SimpleNamespace(**kwargs)


@pytest.mark.asyncio
async def test_clarification_route_returns_router_message_without_llm_call():
    provider = ClarificationProvider()
    message_service = MessageServiceStub()
    service = ChatService(db=None, provider=provider)
    service.message_service = message_service

    result = await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="Remind me",
    )

    assert result[1].content == "What should I remind you about?"
    assert provider.calls == 1
    assert [item["role"] for item in message_service.created] == [
        MessageRole.USER,
        MessageRole.ASSISTANT,
    ]
