from datetime import date, datetime, time, timezone
from types import SimpleNamespace
from uuid import uuid4

import pytest

from app.models.reminder import Reminder
from app.models.task import Task
from app.providers.base import LLMMessage, LLMProvider
from app.repositories.user_repository import UserRepository
from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.executor import ToolExecutor
from app.services.chat_service import ChatService
from app.services.deadline_reminders import plan_deadline_reminders
from app.utils import dates

# Monday 23 Nov 2026, 10:30 in UTC.
NOW = datetime(2026, 11, 23, 10, 30, tzinfo=timezone.utc)


@pytest.fixture(autouse=True)
def frozen_clock(monkeypatch):
    monkeypatch.setattr(dates, "_now", lambda tz=None: NOW)


def _when(planned):
    return [(p.remind_date.isoformat(), p.remind_time.strftime("%H:%M")) for p in planned]


def test_deadline_date_gets_evening_before_and_morning_of():
    planned = plan_deadline_reminders(title="Essay", due_date=date(2026, 11, 27))

    assert _when(planned) == [("2026-11-26", "18:00"), ("2026-11-27", "09:00")]
    assert planned[0].title == "Due tomorrow: Essay"
    assert planned[1].title == "Due today: Essay"


def test_deadline_with_time_reminds_an_hour_before():
    planned = plan_deadline_reminders(
        title="Report", due_date=date(2026, 11, 25), due_time=time(17, 0)
    )

    assert _when(planned) == [("2026-11-24", "18:00"), ("2026-11-25", "16:00")]
    assert planned[1].title == "Due at 17:00: Report"


def test_due_today_after_9am_reminds_in_the_evening():
    planned = plan_deadline_reminders(title="Groceries", due_date=date(2026, 11, 23))

    assert _when(planned) == [("2026-11-23", "18:00")]


def test_deadline_within_the_hour_reminds_at_the_deadline():
    planned = plan_deadline_reminders(
        title="Call", due_date=date(2026, 11, 23), due_time=time(11, 0)
    )

    assert _when(planned) == [("2026-11-23", "11:00")]


def test_past_deadline_and_no_deadline_get_no_reminders():
    assert plan_deadline_reminders(title="Old", due_date=date(2026, 11, 1)) == []
    assert plan_deadline_reminders(title="Someday", due_date=None) == []


def test_user_chosen_reminder_time_wins():
    planned = plan_deadline_reminders(
        title="Essay",
        due_date=date(2026, 11, 27),
        remind_date=date(2026, 11, 25),
        remind_time=time(20, 0),
    )

    assert _when(planned) == [("2026-11-25", "20:00")]


def _user(db):
    return UserRepository.create(
        db,
        email=f"deadline-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )


@pytest.mark.asyncio
async def test_create_task_tool_saves_task_and_its_reminders(db_session):
    user = _user(db_session)
    executor = ToolExecutor.for_user(db_session, user.id)

    result = await executor.execute(
        RouterResponse(
            route="tool",
            tool="create_task",
            arguments={"title": "Submit report", "due_date": "2026-11-25", "due_time": "17:00"},
        )
    )

    task = db_session.query(Task).one()
    assert task.title == "Submit report"

    saved = db_session.query(Reminder).order_by(Reminder.remind_date).all()
    assert [(r.remind_date.isoformat(), r.remind_time.strftime("%H:%M")) for r in saved] == [
        ("2026-11-24", "18:00"),
        ("2026-11-25", "16:00"),
    ]
    assert all(r.user_id == user.id for r in saved)
    assert len(result["reminders"]) == 2


@pytest.mark.asyncio
async def test_bad_time_creates_nothing(db_session):
    user = _user(db_session)
    executor = ToolExecutor.for_user(db_session, user.id)

    with pytest.raises(ValueError):
        await executor.execute(
            RouterResponse(
                route="tool",
                tool="create_task",
                arguments={"title": "X", "due_date": "2026-11-25", "due_time": "lunchish"},
            )
        )

    assert db_session.query(Task).count() == 0
    assert db_session.query(Reminder).count() == 0


class RouterOnly(LLMProvider):
    async def generate(self, messages: list[LLMMessage]) -> str:
        return (
            '{"route":"tool","tool":"create_task","arguments":'
            '{"title":"Submit report","due_date":"2026-11-25","due_time":"17:00"}}'
        )


class Messages:
    def get_recent_messages(self, **kwargs):
        return []

    def create_message(self, **kwargs):
        return SimpleNamespace(**kwargs)


@pytest.mark.asyncio
async def test_chat_reply_says_when_it_will_remind(db_session):
    user = _user(db_session)
    service = ChatService(db=db_session, provider=RouterOnly())
    service.message_service = Messages()

    _, reply = await service.send_message(
        conversation_id=uuid4(),
        user_id=user.id,
        content="Make a task to submit the report by Wednesday 5pm",
    )

    assert reply.content == (
        'Done! I\'ve added the task "Submit report", due Wednesday at 5 PM. '
        "I'll remind you tomorrow at 6 PM and Wednesday at 4 PM."
    )
    assert reply.extra_data["tool"] == "create_task"
