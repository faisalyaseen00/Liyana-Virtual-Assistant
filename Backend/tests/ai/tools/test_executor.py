from uuid import UUID, uuid4

import pytest

from app.models.reminder import Reminder
from app.models.task import Task
from app.repositories.user_repository import UserRepository
from app.services.ai.router.schemas import RouterResponse
from app.services.ai.tools.executor import ToolExecutor


def make_user(db):
    return UserRepository.create(
        db,
        email=f"tools-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )


def tool(name, **arguments):
    return RouterResponse(route="tool", tool=name, arguments=arguments)


@pytest.mark.asyncio
async def test_create_task_is_saved_for_the_user(db_session):
    user = make_user(db_session)
    executor = ToolExecutor.for_user(db_session, user.id)

    result = await executor.execute(
        tool("create_task", title="Submit assignment", due_date="2026-11-30", priority="HIGH")
    )

    task = db_session.query(Task).one()
    assert task.user_id == user.id
    assert task.title == "Submit assignment"
    assert task.due_date.isoformat() == "2026-11-30"
    assert task.priority == "high"
    assert result["id"] == str(task.id)


@pytest.mark.asyncio
async def test_get_tasks_lists_only_this_users_open_tasks(db_session):
    me = make_user(db_session)
    someone_else = make_user(db_session)

    mine = ToolExecutor.for_user(db_session, me.id)
    theirs = ToolExecutor.for_user(db_session, someone_else.id)

    await mine.execute(tool("create_task", title="Mine"))
    done = await mine.execute(tool("create_task", title="Already done"))
    await theirs.execute(tool("create_task", title="Not mine"))

    finished = db_session.get(Task, UUID(done["id"]))
    finished.is_completed = True
    db_session.commit()

    result = await mine.execute(tool("get_tasks"))

    assert [task["title"] for task in result["tasks"]] == ["Mine"]


@pytest.mark.asyncio
async def test_create_reminder_parses_date_and_time(db_session):
    user = make_user(db_session)
    executor = ToolExecutor.for_user(db_session, user.id)

    result = await executor.execute(
        tool("create_reminder", title="Call mom", date="2026-11-24", time="5pm")
    )

    reminder = db_session.query(Reminder).one()
    assert reminder.user_id == user.id
    assert reminder.remind_date.isoformat() == "2026-11-24"
    assert result["time"] == "17:00"


@pytest.mark.asyncio
async def test_unreadable_date_is_rejected_and_nothing_is_saved(db_session):
    user = make_user(db_session)
    executor = ToolExecutor.for_user(db_session, user.id)

    with pytest.raises(ValueError):
        await executor.execute(
            tool("create_reminder", title="Call mom", date="sometime soon")
        )

    assert db_session.query(Reminder).count() == 0


@pytest.mark.asyncio
async def test_list_reminders_returns_open_reminders_soonest_first(db_session):
    user = make_user(db_session)
    executor = ToolExecutor.for_user(db_session, user.id)

    await executor.execute(tool("create_reminder", title="Later", date="2026-12-10"))
    await executor.execute(
        tool("create_reminder", title="Sooner", date="2026-12-01", time="08:00")
    )
    done = await executor.execute(
        tool("create_reminder", title="Finished", date="2026-11-30")
    )
    db_session.get(Reminder, UUID(done["id"])).is_done = True
    db_session.commit()

    result = await executor.execute(tool("list_reminders"))

    assert [r["title"] for r in result["reminders"]] == ["Sooner", "Later"]
    assert result["reminders"][0]["time"] == "08:00"
