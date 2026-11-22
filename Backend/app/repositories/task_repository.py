from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.task import Task


class TaskRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, *, user_id: UUID, **fields) -> Task:
        task = Task(user_id=user_id, **fields)
        self.db.add(task)
        self.db.commit()
        self.db.refresh(task)
        return task

    def get_for_user(self, *, task_id: UUID, user_id: UUID) -> Task | None:
        return self.db.scalar(
            select(Task).where(Task.id == task_id, Task.user_id == user_id)
        )

    def list_for_user(
        self,
        *,
        user_id: UUID,
        completed: bool | None = None,
    ) -> list[Task]:
        statement = select(Task).where(Task.user_id == user_id)

        if completed is not None:
            statement = statement.where(Task.is_completed.is_(completed))

        # Undated tasks last, then by due date, then newest first.
        statement = statement.order_by(
            Task.due_date.is_(None),
            Task.due_date.asc(),
            Task.created_at.desc(),
        )
        return list(self.db.scalars(statement).all())

    def update(self, task: Task, **fields) -> Task:
        for name, value in fields.items():
            setattr(task, name, value)
        self.db.commit()
        self.db.refresh(task)
        return task

    def delete(self, task: Task) -> None:
        self.db.delete(task)
        self.db.commit()
