import re
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError


def is_valid_timezone(name: str) -> bool:
    """True for IANA names such as "Asia/Karachi" or "UTC"."""
    try:
        ZoneInfo(name)
    except (ZoneInfoNotFoundError, ValueError):
        return False
    return True


def _now(tz: str | None = None) -> datetime:
    """Current time in the user's time zone.

    Without a (valid) zone, falls back to the server's local time zone.
    Tests replace this function to freeze the clock.
    """
    if tz and is_valid_timezone(tz):
        return datetime.now(ZoneInfo(tz))
    return datetime.now().astimezone()


def today_label(tz: str | None = None) -> str:
    """Today's date for prompts in the user's time zone, e.g.
    "Monday, 2026-11-23". A UTC date can be a day off for the user, which
    makes "tomorrow" resolve to the wrong day."""
    return _now(tz).strftime("%A, %Y-%m-%d")


def local_today(tz: str | None = None) -> date:
    return _now(tz).date()


def parse_date(value: str | date | None, tz: str | None = None) -> date | None:
    """Parse a date from the AI router: ISO "YYYY-MM-DD", "today" or
    "tomorrow". Raises ValueError for anything else so the assistant asks
    the user again instead of saving a wrong date."""
    if value is None or isinstance(value, date):
        return value

    text = value.strip().lower()
    if not text:
        return None
    if text == "today":
        return local_today(tz)
    if text == "tomorrow":
        return local_today(tz) + timedelta(days=1)

    return date.fromisoformat(text[:10])


_TIME_PATTERN = re.compile(r"^(\d{1,2})(?::(\d{2}))?(?::\d{2})?\s*([ap]\.?m\.?)?$")


def parse_time(value: str | time | None) -> time | None:
    """Parse a time such as "17:00", "5pm" or "5:30 PM". Raises ValueError
    when it can't be understood."""
    if value is None or isinstance(value, time):
        return value

    text = value.strip().lower()
    if not text:
        return None

    match = _TIME_PATTERN.match(text)
    if not match:
        raise ValueError(f"Unrecognised time: {value}")

    hour = int(match.group(1))
    minute = int(match.group(2) or 0)
    meridiem = match.group(3)

    if meridiem:
        if not 1 <= hour <= 12:
            raise ValueError(f"Unrecognised time: {value}")
        hour = hour % 12 + (12 if meridiem.startswith("p") else 0)

    return time(hour, minute)
