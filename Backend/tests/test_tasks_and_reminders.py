from uuid import uuid4

from tests.test_sessions import auth_header, login_user, register_user

PASSWORD = "strong-password-123"


def _headers(client):
    email = f"tasks-{uuid4().hex}@example.com"
    register_user(client, email=email, password=PASSWORD, full_name="Task User")
    token = login_user(client, email=email, password=PASSWORD).json()["access_token"]
    return auth_header(token)


def test_task_lifecycle(client):
    headers = _headers(client)

    created = client.post(
        "/api/v1/tasks",
        headers=headers,
        json={"title": "  Write report  ", "priority": "high", "due_date": "2026-12-01"},
    )
    assert created.status_code == 201
    task = created.json()
    assert task["title"] == "Write report"
    assert task["priority"] == "high"
    assert task["is_completed"] is False

    listed = client.get("/api/v1/tasks", headers=headers).json()
    assert [t["id"] for t in listed] == [task["id"]]

    done = client.patch(
        f"/api/v1/tasks/{task['id']}",
        headers=headers,
        json={"is_completed": True},
    ).json()
    assert done["is_completed"] is True
    assert done["completed_at"] is not None
    assert done["title"] == "Write report"  # untouched fields stay

    assert client.get("/api/v1/tasks?completed=false", headers=headers).json() == []
    assert len(client.get("/api/v1/tasks?completed=true", headers=headers).json()) == 1

    cleared = client.patch(
        f"/api/v1/tasks/{task['id']}",
        headers=headers,
        json={"due_date": None},
    ).json()
    assert cleared["due_date"] is None

    deleted = client.delete(f"/api/v1/tasks/{task['id']}", headers=headers)
    assert deleted.status_code == 204
    assert client.get(f"/api/v1/tasks/{task['id']}", headers=headers).status_code == 404


def test_tasks_are_private_to_their_owner(client):
    owner = _headers(client)
    stranger = _headers(client)

    task_id = client.post(
        "/api/v1/tasks",
        headers=owner,
        json={"title": "Private"},
    ).json()["id"]

    assert client.get("/api/v1/tasks", headers=stranger).json() == []
    assert client.get(f"/api/v1/tasks/{task_id}", headers=stranger).status_code == 404
    assert client.delete(f"/api/v1/tasks/{task_id}", headers=stranger).status_code == 404
    assert client.get(f"/api/v1/tasks/{task_id}", headers=owner).status_code == 200


def test_task_validation(client):
    headers = _headers(client)

    assert client.post("/api/v1/tasks", headers=headers, json={"title": " "}).status_code == 422
    assert (
        client.post(
            "/api/v1/tasks",
            headers=headers,
            json={"title": "x", "priority": "urgent"},
        ).status_code
        == 422
    )
    assert client.get("/api/v1/tasks").status_code in (401, 403)


def test_reminder_lifecycle(client):
    headers = _headers(client)

    created = client.post(
        "/api/v1/reminders",
        headers=headers,
        json={"title": "Call mom", "remind_date": "2026-11-24", "remind_time": "17:00"},
    )
    assert created.status_code == 201
    reminder = created.json()
    assert reminder["remind_time"] == "17:00:00"

    later = client.post(
        "/api/v1/reminders",
        headers=headers,
        json={"title": "Dentist", "remind_date": "2026-12-05"},
    ).json()

    listed = client.get("/api/v1/reminders", headers=headers).json()
    assert [r["title"] for r in listed] == ["Call mom", "Dentist"]

    done = client.patch(
        f"/api/v1/reminders/{reminder['id']}",
        headers=headers,
        json={"is_done": True},
    ).json()
    assert done["is_done"] is True

    open_only = client.get("/api/v1/reminders?done=false", headers=headers).json()
    assert [r["id"] for r in open_only] == [later["id"]]

    assert (
        client.delete(f"/api/v1/reminders/{reminder['id']}", headers=headers).status_code
        == 204
    )
