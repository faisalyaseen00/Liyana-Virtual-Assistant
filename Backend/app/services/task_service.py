from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.task import Task
from app.repositories.task_repository import TaskRepository
from app.schemas.task import TaskCreate, TaskUpdate
from app.utils.dates import parse_date

PRIORITIES = {"low", "medium", "high"}


def task_to_dict(task: Task) -> dict[str, Any]:
    """JSON-safe summary, stored in the assistant message's metadata."""
    return {
        "id": str(task.id),
        "title": task.title,
        "priority": task.priority,
        "due_date": task.due_date.isoformat() if task.due_date else None,
        "is_completed": task.is_completed,
    }


class TaskService:
    """Tasks for one user, used by the REST API and the AI tools."""

    def __init__(self, db: Session, user_id: UUID, tz: str | None = None):
        # The user's IANA time zone, for "today" / "tomorrow" in AI requests.
        self.tz = tz
        self.repository = TaskRepository(db)
        self.user_id = user_id

    # ---------- REST API ----------

    def list_tasks(self, completed: bool | None = None) -> list[Task]:
        return self.repository.list_for_user(
            user_id=self.user_id,
            completed=completed,
        )

    def get(self, task_id: UUID) -> Task | None:
        return self.repository.get_for_user(task_id=task_id, user_id=self.user_id)

    def create(self, data: TaskCreate) -> Task:
        return self.repository.create(user_id=self.user_id, **data.model_dump())

    def update(self, task_id: UUID, data: TaskUpdate) -> Task | None:
        task = self.get(task_id)
        if task is None:
            return None

        fields = data.model_dump(exclude_unset=True)

        # Only due_date may be cleared with null; other nulls mean "no change".
        fields = {
            name: value
            for name, value in fields.items()
            if value is not None or name == "due_date"
        }

        if "is_completed" in fields:
            fields["completed_at"] = (
                datetime.now(timezone.utc) if fields["is_completed"] else None
            )

        return self.repository.update(task, **fields)

    def delete(self, task_id: UUID) -> bool:
        task = self.get(task_id)
        if task is None:
            return False
        self.repository.delete(task)
        return True

    # ---------- AI tools ----------

    async def create_task(
        self,
        *,
        title: str,
        due_date: str | None = None,
        description: str | None = None,
        priority: str | None = None,
        **_: Any,
    ) -> dict[str, Any]:
        if not title or not str(title).strip():
            raise ValueError("A task needs a title")

        priority = (priority or "medium").strip().lower()
        if priority not in PRIORITIES:
            priority = "medium"

        task = self.repository.create(
            user_id=self.user_id,
            title=str(title).strip()[:255],
            description=(description or "").strip(),
            priority=priority,
            due_date=parse_date(due_date, self.tz),
        )
        return task_to_dict(task)

    async def get_tasks(self, **_: Any) -> dict[str, list[dict[str, Any]]]:
        return {"tasks": [task_to_dict(task) for task in self.list_tasks(completed=False)]}
