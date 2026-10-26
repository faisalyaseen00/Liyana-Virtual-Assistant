from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.models.enums import MessageRole
from app.providers.base import LLMMessage, LLMProvider
from app.services.chat_service import ChatService


class ToolProvider(LLMProvider):
    def __init__(self, router_reply: str):
        self.router_reply = router_reply
        self.calls = 0

    async def generate(self, messages: list[LLMMessage]) -> str:
        self.calls += 1
        if self.calls > 1:
            raise AssertionError("The conversational LLM must not be called")
        return self.router_reply


class MessageServiceStub:
    def __init__(self):
        self.created = []

    def get_recent_messages(self, **kwargs):
        return []

    def create_message(self, **kwargs):
        self.created.append(kwargs)
        return SimpleNamespace(**kwargs)


@pytest.mark.asyncio
async def test_tool_route_runs_tool_and_saves_result():
    provider = ToolProvider(
        '{"route":"tool","tool":"create_task",'
        '"arguments":{"title":"Submit assignment","due_date":"2026-11-01"}}'
    )
    message_service = MessageServiceStub()
    service = ChatService(db=None, provider=provider)
    service.message_service = message_service

    result = await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="Create a task to submit my assignment by Nov 1",
    )

    assistant = result[1]
    assert assistant.content == "Task created: Submit assignment (due 2026-11-01)."
    assert assistant.extra_data["tool"] == "create_task"
    assert assistant.extra_data["result"]["title"] == "Submit assignment"
    assert [item["role"] for item in message_service.created] == [
        MessageRole.USER,
        MessageRole.ASSISTANT,
    ]


@pytest.mark.asyncio
async def test_tool_route_with_missing_arguments_asks_for_details():
    provider = ToolProvider('{"route":"tool","tool":"create_reminder","arguments":{}}')
    service = ChatService(db=None, provider=provider)
    service.message_service = MessageServiceStub()

    result = await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="Remind me",
    )

    assert "more details" in result[1].content
    assert result[1].extra_data["error"] == "invalid_arguments"
