import pytest

from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.executor import ToolExecutor


@pytest.mark.asyncio
@pytest.mark.parametrize(
    ("tool_name", "arguments", "expected_key", "expected_value"),
    [
        ("create_task", {"title": "Submit assignment"}, "title", "Submit assignment"),
        ("get_tasks", {}, "tasks", []),
        ("create_reminder", {"title": "Submit assignment", "date": "2026-10-03", "time": "09:00"}, "title", "Submit assignment"),
    ],
)
async def test_tool_executor_dispatches_registered_services(
    tool_name,
    arguments,
    expected_key,
    expected_value,
):
    executor = ToolExecutor()
    response = RouterResponse(
        route="tool",
        tool=tool_name,
        arguments=arguments,
    )

    result = await executor.execute(response)

    assert result is not None
    assert result[expected_key] == expected_value
