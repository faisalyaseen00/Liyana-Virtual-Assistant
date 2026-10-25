from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.registery import tool_registry


def validate_router_response(response: RouterResponse) -> RouterResponse:
    if response.route == "tool":
        if not response.tool:
            raise ValueError("Tool route requires a tool")

        tool = tool_registry.get(response.tool)

        if not tool:
            raise ValueError(f"Unknown tool: {response.tool}")

    return response