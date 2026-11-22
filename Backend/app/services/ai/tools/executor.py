from collections.abc import Awaitable, Callable
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.services.ai.router.schemas import RouterResponse
from app.services.ai.router.validator import validate_router_response
from app.services.reminder_service import ReminderService
from app.services.task_service import TaskService

ToolHandler = Callable[..., Awaitable[Any]]


class ToolExecutor:
    def __init__(self, services: dict[str, ToolHandler]):
        self.services = services

    @classmethod
    def for_user(
        cls,
        db: Session,
        user_id: UUID,
        tz: str | None = None,
    ) -> "ToolExecutor":
        """Tools that read and write the given user's tasks and reminders.
        `tz` is the user's IANA time zone, used for "today" / "tomorrow"."""
        tasks = TaskService(db, user_id, tz)
        reminders = ReminderService(db, user_id, tz)

        return cls(
            {
                "create_task": tasks.create_task,
                "get_tasks": tasks.get_tasks,
                "create_reminder": reminders.create_reminder,
                "list_reminders": reminders.get_reminders,
            }
        )

    async def execute(self, response: RouterResponse):
        response = validate_router_response(response)

        if response.route != "tool":
            return None

        service = self.services.get(response.tool)

        if not service:
            raise ValueError(f"No service registered for: {response.tool}")

        return await service(**response.arguments)
