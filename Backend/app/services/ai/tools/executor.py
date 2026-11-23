from collections.abc import Awaitable, Callable
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.services.ai.router.schemas import RouterResponse
from app.services.ai.router.validator import validate_router_response
from app.services.deadline_reminders import plan_deadline_reminders
from app.services.reminder_service import ReminderService, reminder_to_dict
from app.services.task_service import TaskService
from app.utils.dates import parse_date, parse_time

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

        async def create_task(
            *,
            title: str,
            due_date: str | None = None,
            due_time: str | None = None,
            remind_date: str | None = None,
            remind_time: str | None = None,
            **kwargs: Any,
        ) -> dict[str, Any]:
            """Create the task, then the reminders its deadline calls for,
            like a real assistant would."""
            # Parse everything first so a bad time doesn't leave a task
            # behind without its reminders.
            parsed_due_time = parse_time(due_time)
            parsed_remind_date = parse_date(remind_date, tz)
            parsed_remind_time = parse_time(remind_time)

            task = await tasks.create_task(title=title, due_date=due_date, **kwargs)

            planned = plan_deadline_reminders(
                title=task["title"],
                due_date=parse_date(task["due_date"], tz),
                due_time=parsed_due_time,
                remind_date=parsed_remind_date,
                remind_time=parsed_remind_time,
                tz=tz,
            )
            task["due_time"] = (
                parsed_due_time.strftime("%H:%M") if parsed_due_time else None
            )
            task["reminders"] = [
                reminder_to_dict(
                    reminders.repository.create(
                        user_id=user_id,
                        title=item.title[:255],
                        remind_date=item.remind_date,
                        remind_time=item.remind_time,
                    )
                )
                for item in planned
            ]
            return task

        return cls(
            {
                "create_task": create_task,
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
