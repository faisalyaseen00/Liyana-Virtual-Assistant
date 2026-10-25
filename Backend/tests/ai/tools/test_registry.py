from app.services.ai.tools.defination import ToolDefinition
from app.services.ai.tools.registery import ToolRegistry


def test_register_and_get_tool():
    registry = ToolRegistry()

    tool = ToolDefinition(
        name="create_task",
        description="Create a new task for the user.",
        parameters={
            "title": {
                "type": "string",
                "required": True,
            }
        },
    )

    registry.register(tool)

    result = registry.get("create_task")

    assert result is not None
    assert result.name == "create_task"


def test_tool_exists():
    registry = ToolRegistry()

    tool = ToolDefinition(
        name="create_task",
        description="Create a new task for the user.",
    )

    registry.register(tool)

    assert registry.exists("create_task")
    assert not registry.exists("delete_task")


def test_duplicate_tool_is_rejected():
    registry = ToolRegistry()

    tool = ToolDefinition(
        name="create_task",
        description="Create a new task for the user.",
    )

    registry.register(tool)

    try:
        registry.register(tool)
        assert False
    except ValueError:
        assert True