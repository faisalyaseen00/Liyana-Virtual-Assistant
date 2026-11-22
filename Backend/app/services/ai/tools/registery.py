from app.services.ai.tools.defination import ToolDefinition
from app.services.ai.tools.defination import (
    CREATE_TASK,
    GET_TASKS,
    CREATE_REMINDER,
    LIST_REMINDERS,
)





class ToolRegistry:
    def __init__(self):
        self._tools: dict[str, ToolDefinition] = {}

    def register(self, tool: ToolDefinition) -> None:
        if tool.name in self._tools:
            raise ValueError(f"Tool already registered: {tool.name}")

        self._tools[tool.name] = tool

    def get(self, name: str) -> ToolDefinition | None:
        return self._tools.get(name)

    def exists(self, name: str) -> bool:
        return name in self._tools

    def list_tools(self) -> list[ToolDefinition]:
        return list(self._tools.values())
tool_registry = ToolRegistry()

tool_registry.register(CREATE_TASK)
tool_registry.register(GET_TASKS)
tool_registry.register(CREATE_REMINDER)
tool_registry.register(LIST_REMINDERS)