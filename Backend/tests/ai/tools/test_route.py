import pytest

from app.services.ai.router.semantic_router import SemanticRouter
from app.providers.base import LLMMessage, LLMProvider


class FakeProvider(LLMProvider):
    async def generate(self, messages: list[LLMMessage]) -> str:
        user_prompt = messages[-1].content

        if "Create a task to submit my assignment" in user_prompt:
            return '{"route":"tool","tool":"create_task","arguments":{"title":"Submit my assignment"}}'

        if "Explain SQL injection" in user_prompt:
            return '{"route":"conversation","message":"I can explain SQL injection."}'

        return '{"route":"clarification","message":"What should I remind you about?"}'


@pytest.mark.asyncio
async def test_tool_route():
    router = SemanticRouter(FakeProvider())

    result = await router.route(
        "Create a task to submit my assignment"
    )

    assert result.route == "tool"


@pytest.mark.asyncio
async def test_conversation_route():
    router = SemanticRouter(FakeProvider())

    result = await router.route(
        "Explain SQL injection"
    )

    assert result.route == "conversation"


@pytest.mark.asyncio
async def test_clarification_route():
    router = SemanticRouter(FakeProvider())

    result = await router.route(
        "Remind me"
    )

    assert result.route == "clarification"