from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.models.reminder import Reminder
from app.repositories.reminder_repository import ReminderRepository
from app.schemas.reminder import ReminderCreate, ReminderUpdate
from app.utils.dates import parse_date, parse_time


def reminder_to_dict(reminder: Reminder) -> dict[str, Any]:
    """JSON-safe summary, stored in the assistant message's metadata."""
    return {
        "id": str(reminder.id),
        "title": reminder.title,
        "date": reminder.remind_date.isoformat(),
        "time": reminder.remind_time.strftime("%H:%M") if reminder.remind_time else None,
        "is_done": reminder.is_done,
    }


class ReminderService:
    """Reminders for one user, used by the REST API and the AI tools."""

    def __init__(self, db: Session, user_id: UUID, tz: str | None = None):
        # The user's IANA time zone, for "today" / "tomorrow" in AI requests.
        self.tz = tz
        self.repository = ReminderRepository(db)
        self.user_id = user_id

    # ---------- REST API ----------

    def list_reminders(self, done: bool | None = None) -> list[Reminder]:
        return self.repository.list_for_user(user_id=self.user_id, done=done)

    def get(self, reminder_id: UUID) -> Reminder | None:
        return self.repository.get_for_user(
            reminder_id=reminder_id,
            user_id=self.user_id,
        )

    def create(self, data: ReminderCreate) -> Reminder:
        return self.repository.create(user_id=self.user_id, **data.model_dump())

    def update(self, reminder_id: UUID, data: ReminderUpdate) -> Reminder | None:
        reminder = self.get(reminder_id)
        if reminder is None:
            return None

        fields = data.model_dump(exclude_unset=True)
        # Only remind_time may be cleared with null; other nulls mean "no change".
        fields = {
            name: value
            for name, value in fields.items()
            if value is not None or name == "remind_time"
        }
        return self.repository.update(reminder, **fields)

    def delete(self, reminder_id: UUID) -> bool:
        reminder = self.get(reminder_id)
        if reminder is None:
            return False
        self.repository.delete(reminder)
        return True

    # ---------- AI tools ----------

    async def create_reminder(
        self,
        *,
        title: str,
        date: str,
        time: str | None = None,
        **_: Any,
    ) -> dict[str, Any]:
        if not title or not str(title).strip():
            raise ValueError("A reminder needs a title")

        remind_date = parse_date(date, self.tz)
        if remind_date is None:
            raise ValueError("A reminder needs a date")

        reminder = self.repository.create(
            user_id=self.user_id,
            title=str(title).strip()[:255],
            remind_date=remind_date,
            remind_time=parse_time(time),
        )
        return reminder_to_dict(reminder)

    async def get_reminders(self, **_: Any) -> dict[str, list[dict[str, Any]]]:
        """Open (not done) reminders, soonest first."""
        return {
            "reminders": [
                reminder_to_dict(reminder)
                for reminder in self.list_reminders(done=False)
            ]
        }
