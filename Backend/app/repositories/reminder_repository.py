from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.reminder import Reminder


class ReminderRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(self, *, user_id: UUID, **fields) -> Reminder:
        reminder = Reminder(user_id=user_id, **fields)
        self.db.add(reminder)
        self.db.commit()
        self.db.refresh(reminder)
        return reminder

    def get_for_user(
        self,
        *,
        reminder_id: UUID,
        user_id: UUID,
    ) -> Reminder | None:
        return self.db.scalar(
            select(Reminder).where(
                Reminder.id == reminder_id,
                Reminder.user_id == user_id,
            )
        )

    def list_for_user(
        self,
        *,
        user_id: UUID,
        done: bool | None = None,
    ) -> list[Reminder]:
        statement = select(Reminder).where(Reminder.user_id == user_id)

        if done is not None:
            statement = statement.where(Reminder.is_done.is_(done))

        statement = statement.order_by(
            Reminder.remind_date.asc(),
            Reminder.remind_time.is_(None),
            Reminder.remind_time.asc(),
        )
        return list(self.db.scalars(statement).all())

    def update(self, reminder: Reminder, **fields) -> Reminder:
        for name, value in fields.items():
            setattr(reminder, name, value)
        self.db.commit()
        self.db.refresh(reminder)
        return reminder

    def delete(self, reminder: Reminder) -> None:
        self.db.delete(reminder)
        self.db.commit()
