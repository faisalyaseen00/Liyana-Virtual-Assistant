from app.services.ai.router.schemas import RouterResponse
from app.services.ai.router.validator import validate_router_response
from app.services.task_service import TaskService
from app.services.reminder_service import ReminderService


DEFAULT_SERVICES = {
    "create_task": TaskService().create_task,
    "get_tasks": TaskService().get_tasks,
    "create_reminder": ReminderService().create_reminder,
}


class ToolExecutor:
    def __init__(self, services: dict | None = None):
        self.services = services or DEFAULT_SERVICES

    async def execute(self, response: RouterResponse):
        response = validate_router_response(response)

        if response.route != "tool":
            return None

        service = self.services.get(response.tool)

        if not service:
            raise ValueError(f"No service registered for: {response.tool}")

        return await service(**response.arguments)