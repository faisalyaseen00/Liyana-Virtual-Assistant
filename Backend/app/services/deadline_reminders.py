"""Reminders that Liyana sets on its own when a task has a deadline.

The rule, in the user's local time:
- The user said when to be reminded -> exactly that one reminder.
- Deadline with a time  -> 1 hour before it, plus the evening before
  (18:00) when the deadline is on a later day.
- Deadline without time -> 09:00 on the due day, plus the evening before.
- Reminders that would already be in the past are skipped; a task due
  today whose 09:00 has passed gets one at 18:00 if that is still ahead.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta

from app.utils import dates

DAY_BEFORE_AT = time(18, 0)
DUE_DAY_AT = time(9, 0)
LATE_DUE_DAY_AT = time(18, 0)
BEFORE_DEADLINE = timedelta(hours=1)


@dataclass(frozen=True)
class PlannedReminder:
    title: str
    remind_date: date
    remind_time: time


def _short_title(title: str) -> str:
    return title.strip()[:200]


def plan_deadline_reminders(
    *,
    title: str,
    due_date: date | None,
    due_time: time | None = None,
    remind_date: date | None = None,
    remind_time: time | None = None,
    tz: str | None = None,
) -> list[PlannedReminder]:
    name = _short_title(title)

    # The user said when; do exactly that.
    if remind_date is not None or remind_time is not None:
        when_date = remind_date or due_date or dates.local_today(tz)
        return [
            PlannedReminder(
                title=name,
                remind_date=when_date,
                remind_time=remind_time or DUE_DAY_AT,
            )
        ]

    if due_date is None:
        return []

    now = dates._now(tz).replace(tzinfo=None, second=0, microsecond=0)
    planned: list[PlannedReminder] = []

    def add(day: date, at: time, label: str) -> None:
        if datetime.combine(day, at) > now:
            planned.append(PlannedReminder(f"{label}: {name}", day, at))

    day_before = due_date - timedelta(days=1)
    add(day_before, DAY_BEFORE_AT, "Due tomorrow")

    if due_time is not None:
        deadline = datetime.combine(due_date, due_time)
        before = deadline - BEFORE_DEADLINE
        # Deadline within the next hour: remind right at the deadline.
        if before <= now < deadline:
            before = deadline
        add(before.date(), before.time(), f"Due at {due_time:%H:%M}")
    else:
        add(due_date, DUE_DAY_AT, "Due today")
        if not any(p.remind_date == due_date for p in planned):
            add(due_date, LATE_DUE_DAY_AT, "Due today")

    return planned
