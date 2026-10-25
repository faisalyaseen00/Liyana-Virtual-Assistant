from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.ai.context.builder import ContextBuilder
from app.models.enums import MessageRole
from app.providers.base import LLMMessage, LLMProvider
from app.services.chat_service import ChatService
from app.services.ai.router.schemas import RouterResponse


class NoCallProvider(LLMProvider):
    async def generate(self, messages: list[LLMMessage]) -> str:
        raise AssertionError("The provider should not be called by this test")


class UserRepositoryStub:
    @staticmethod
    def get_by_id(db, user_id):
        return SimpleNamespace(
            full_name="Ada Lovelace",
            timezone="UTC",
            language="en",
        )


class MessageServiceStub:
    def __init__(self):
        self.history = [
            SimpleNamespace(
                role=MessageRole.USER,
                content="A short previous request",
            )
        ]
        self.created = []

    def get_recent_messages(self, **kwargs):
        return self.history

    def create_message(self, **kwargs):
        self.created.append(kwargs)
        return SimpleNamespace(**kwargs)


class RouterStub:
    def __init__(self):
        self.context = None

    async def route(self, user_input, context=""):
        self.context = context
        return RouterResponse(
            route="clarification",
            message="Please provide more details.",
        )


@pytest.mark.asyncio
async def test_context_builder_passes_profile_and_history_to_router():
    context_builder = ContextBuilder(
        db=object(),
        message_service=MessageServiceStub(),
        user_repository=UserRepositoryStub,
    )
    router = RouterStub()
    service = ChatService(
        db=None,
        provider=NoCallProvider(),
        context_builder=context_builder,
    )
    service.message_service = MessageServiceStub()
    service.router = router

    await service.send_message(
        conversation_id=uuid4(),
        user_id=uuid4(),
        content="Remind me",
    )

    assert router.context == (
        "User: name=Ada Lovelace; timezone=UTC; language=en\n"
        "Recent conversation:\n"
        "- user: A short previous request"
    )
