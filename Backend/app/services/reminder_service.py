from typing import Any


class ReminderService:
    """Thin reminder service layer for the Liyana tool executor."""

    async def create_reminder(
        self,
        *,
        title: str,
        date: str,
        time: str | None = None,
        **_: Any,
    ) -> dict[str, Any]:
        return {
            "title": title,
            "date": date,
            "time": time,
        }
