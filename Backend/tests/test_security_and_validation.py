from uuid import uuid4

from tests.test_sessions import auth_header, login_user, register_user

PASSWORD = "strong-password-123"


def _login(client):
    email = f"user-{uuid4().hex}@example.com"
    register_user(client, email=email, password=PASSWORD, full_name="Test User")
    return login_user(client, email=email, password=PASSWORD).json()


def test_logout_revokes_the_access_token(client):
    tokens = _login(client)
    headers = auth_header(tokens["access_token"])

    assert client.get("/api/v1/users/me", headers=headers).status_code == 200

    logout = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": tokens["refresh_token"]},
    )
    assert logout.status_code == 200

    assert client.get("/api/v1/users/me", headers=headers).status_code == 401


def test_message_cannot_be_deleted_through_another_conversation(client):
    headers = auth_header(_login(client)["access_token"])

    first = client.post("/api/v1/conversations", headers=headers).json()["id"]
    second = client.post("/api/v1/conversations", headers=headers).json()["id"]

    message = client.post(
        f"/api/v1/conversations/{first}/messages",
        headers=headers,
        json={"role": "user", "content": "keep me"},
    ).json()

    wrong = client.delete(
        f"/api/v1/conversations/{second}/messages/{message['id']}",
        headers=headers,
    )
    assert wrong.status_code == 404

    still_there = client.get(
        f"/api/v1/conversations/{first}/messages/{message['id']}",
        headers=headers,
    )
    assert still_there.status_code == 200


def test_blank_chat_message_and_long_title_are_rejected(client):
    headers = auth_header(_login(client)["access_token"])
    conversation = client.post("/api/v1/conversations", headers=headers).json()["id"]

    blank = client.post(
        f"/api/v1/conversations/{conversation}/chat",
        headers=headers,
        json={"content": "   "},
    )
    assert blank.status_code == 422

    long_title = client.patch(
        f"/api/v1/conversations/{conversation}",
        headers=headers,
        json={"title": "x" * 300},
    )
    assert long_title.status_code == 422
