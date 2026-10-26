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

def test_router_output_wrapped_in_code_fence_is_parsed():
    from app.services.ai.router.semantic_router import parse_router_output

    raw = 'Sure!\n```json\n{"route":"tool","tool":"get_tasks","arguments":{}}\n```'

    result = parse_router_output(raw)

    assert result.route == "tool"
    assert result.tool == "get_tasks"


def test_router_output_that_is_not_json_falls_back_to_conversation():
    from app.services.ai.router.semantic_router import parse_router_output

    assert parse_router_output("Hello there!").route == "conversation"


def test_router_output_with_unknown_tool_falls_back_to_conversation():
    from app.services.ai.router.semantic_router import parse_router_output

    result = parse_router_output('{"route":"tool","tool":"launch_rocket"}')

    assert result.route == "conversation"
