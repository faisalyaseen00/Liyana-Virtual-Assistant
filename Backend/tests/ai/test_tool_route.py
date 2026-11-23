from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.models.enums import MessageRole
from app.models.task import Task
from app.providers.base import LLMMessage, LLMProvider
from app.repositories.user_repository import UserRepository
from app.services.chat_service import ChatService


class ToolProvider(LLMProvider):
    def __init__(self, router_reply: str):
        self.router_reply = router_reply
        self.calls = 0

    async def generate(self, messages: list[LLMMessage]) -> str:
        self.calls += 1
        # Later calls are the router's second look after a failed tool;
        # repeating the same answer makes it give up and ask the user.
        if self.calls > 2:
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
async def test_tool_route_runs_tool_and_saves_result(db_session):
    user = UserRepository.create(
        db_session,
        email=f"chat-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )
    provider = ToolProvider(
        '{"route":"tool","tool":"create_task",'
        '"arguments":{"title":"Submit assignment","due_date":"2026-11-01"}}'
    )
    message_service = MessageServiceStub()
    service = ChatService(db=db_session, provider=provider)
    service.message_service = message_service

    result = await service.send_message(
        conversation_id=uuid4(),
        user_id=user.id,
        content="Create a task to submit my assignment by Nov 1",
    )

    assistant = result[1]
    # The deadline is in the past, so there is nothing left to remind about.
    assert assistant.content == (
        'Done! I\'ve added the task "Submit assignment", due Sunday 1 Nov.'
    )
    assert assistant.extra_data["tool"] == "create_task"
    assert assistant.extra_data["result"]["title"] == "Submit assignment"

    # The task really is in the database for this user.
    task = db_session.query(Task).one()
    assert task.user_id == user.id
    assert task.title == "Submit assignment"
    assert [item["role"] for item in message_service.created] == [
        MessageRole.USER,
        MessageRole.ASSISTANT,
    ]


@pytest.mark.asyncio
async def test_tool_route_with_missing_arguments_asks_for_details(db_session):
    provider = ToolProvider('{"route":"tool","tool":"create_reminder","arguments":{}}')
    service = ChatService(db=db_session, provider=provider)
    service.message_service = MessageServiceStub()

    result = await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="Remind me",
    )

    assert "more details" in result[1].content
    assert result[1].extra_data["error"] == "invalid_arguments"


class ScriptedProvider(LLMProvider):
    """Returns the given replies in order, one per call."""

    def __init__(self, *replies: str):
        self.replies = list(replies)
        self.calls: list[list[LLMMessage]] = []

    async def generate(self, messages: list[LLMMessage]) -> str:
        self.calls.append(messages)
        return self.replies.pop(0)


@pytest.mark.asyncio
async def test_bad_arguments_are_repaired_by_the_llm(db_session):
    user = UserRepository.create(
        db_session,
        email=f"repair-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )
    provider = ScriptedProvider(
        '{"route":"tool","tool":"create_task",'
        '"arguments":{"title":"Pay bill","due_date":"next fri"}}',
        '{"route":"tool","tool":"create_task",'
        '"arguments":{"title":"Pay bill","due_date":"2030-01-04"}}',
    )
    service = ChatService(db=db_session, provider=provider)
    service.message_service = MessageServiceStub()

    _, reply = await service.send_message(
        conversation_id=uuid4(),
        user_id=user.id,
        content="add task pay bill next fri",
    )

    assert reply.content.startswith('Done! I\'ve added the task "Pay bill"')
    assert reply.extra_data["repaired"] is True
    assert db_session.query(Task).one().due_date.isoformat() == "2030-01-04"
    # The second look saw what went wrong.
    assert "could not be done" in provider.calls[1][-1].content


@pytest.mark.asyncio
async def test_repair_can_ask_a_specific_question(db_session):
    provider = ScriptedProvider(
        '{"route":"tool","tool":"create_reminder","arguments":{"title":"call"}}',
        '{"route":"clarification","message":"Who should I remind you to call, and when?"}',
    )
    service = ChatService(db=db_session, provider=provider)
    service.message_service = MessageServiceStub()

    _, reply = await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="remind me to call",
    )

    assert reply.content == "Who should I remind you to call, and when?"
    assert reply.extra_data["error"] == "invalid_arguments"
