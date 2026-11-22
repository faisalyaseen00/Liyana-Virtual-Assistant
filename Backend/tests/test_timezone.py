from datetime import datetime, timezone
from uuid import uuid4
from zoneinfo import ZoneInfo

import pytest

from app.models.reminder import Reminder
from app.repositories.user_repository import UserRepository
from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.executor import ToolExecutor
from app.utils import dates
from tests.test_sessions import auth_header, login_user, register_user

# 20:30 UTC on Nov 23 is already 01:30 on Nov 24 in Karachi (UTC+5),
# but still 12:30 on Nov 23 in Los Angeles (UTC-8).
FROZEN_UTC = datetime(2026, 11, 23, 20, 30, tzinfo=timezone.utc)


@pytest.fixture()
def frozen_clock(monkeypatch):
    def fake_now(tz=None):
        zone = ZoneInfo(tz) if tz and dates.is_valid_timezone(tz) else timezone.utc
        return FROZEN_UTC.astimezone(zone)

    monkeypatch.setattr(dates, "_now", fake_now)


@pytest.mark.parametrize(
    ("tz", "today", "tomorrow"),
    [
        ("Asia/Karachi", "2026-11-24", "2026-11-25"),
        ("America/Los_Angeles", "2026-11-23", "2026-11-24"),
        ("UTC", "2026-11-23", "2026-11-24"),
    ],
)
def test_today_and_tomorrow_follow_the_users_timezone(frozen_clock, tz, today, tomorrow):
    assert dates.parse_date("today", tz).isoformat() == today
    assert dates.parse_date("tomorrow", tz).isoformat() == tomorrow
    assert today in dates.today_label(tz)


def test_unknown_timezone_falls_back_instead_of_crashing():
    assert dates.is_valid_timezone("Not/AZone") is False
    assert dates.today_label("Not/AZone")  # server local time, no error


@pytest.mark.asyncio
async def test_reminder_for_tomorrow_uses_the_users_date(db_session, frozen_clock):
    user = UserRepository.create(
        db_session,
        email=f"tz-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )
    executor = ToolExecutor.for_user(db_session, user.id, "Asia/Karachi")

    await executor.execute(
        RouterResponse(
            route="tool",
            tool="create_reminder",
            arguments={"title": "Call mom", "date": "tomorrow", "time": "5pm"},
        )
    )

    reminder = db_session.query(Reminder).one()
    assert reminder.remind_date.isoformat() == "2026-11-25"


def test_profile_accepts_real_timezones_only(client):
    email = f"tz-{uuid4().hex}@example.com"
    register_user(client, email=email, password="strong-password-123", full_name="Tz")
    token = login_user(client, email=email, password="strong-password-123").json()[
        "access_token"
    ]
    headers = auth_header(token)

    ok = client.patch("/api/v1/users/me", headers=headers, json={"timezone": "Asia/Karachi"})
    assert ok.status_code == 200
    assert ok.json()["timezone"] == "Asia/Karachi"

    bad = client.patch("/api/v1/users/me", headers=headers, json={"timezone": "Mars/Base"})
    assert bad.status_code == 422
    assert client.get("/api/v1/users/me", headers=headers).json()["timezone"] == "Asia/Karachi"
