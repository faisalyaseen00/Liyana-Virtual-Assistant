from uuid import UUID, uuid4

from app.models.session import Session as UserSession
from app.utils.jwt import decode_token


def register_user(client, *, email: str, password: str, full_name: str):
    return client.post(
        "/api/v1/auth/register",
        json={
            "email": email,
            "password": password,
            "full_name": full_name,
        },
    )


def login_user(client, *, email: str, password: str):
    return client.post(
        "/api/v1/auth/login",
        json={
            "email": email,
            "password": password,
        },
    )


def auth_header(access_token: str) -> dict[str, str]:
    return {"Authorization": f"Bearer {access_token}"}


def test_list_sessions_and_revoke_other_sessions(client, db_session):
    email = f"sessions-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Session User",
    )
    assert register_response.status_code == 201

    first_login = login_user(client, email=email, password=password)
    assert first_login.status_code == 200
    first_access_token = first_login.json()["access_token"]

    second_login = login_user(client, email=email, password=password)
    assert second_login.status_code == 200
    second_access_token = second_login.json()["access_token"]

    sessions_response = client.get(
        "/api/v1/sessions/",
        headers=auth_header(first_access_token),
    )
    assert sessions_response.status_code == 200
    sessions = sessions_response.json()
    assert len(sessions) == 2
    assert sum(1 for session in sessions if session["is_current"]) == 1

    current_session_id = UUID(decode_token(first_access_token)["session_id"])
    revoke_others_response = client.delete(
        "/api/v1/sessions/",
        headers=auth_header(first_access_token),
    )
    assert revoke_others_response.status_code == 204

    db_session.expire_all()
    current_session = db_session.get(UserSession, current_session_id)
    assert current_session is not None
    assert current_session.is_active is True

    other_session_id = UUID(decode_token(second_access_token)["session_id"])
    other_session = db_session.get(UserSession, other_session_id)
    assert other_session is not None
    assert other_session.is_active is False


def test_revoke_single_session_and_forbidden_for_other_user(client, db_session):
    first_email = f"session-owner-{uuid4().hex}@example.com"
    second_email = f"session-other-{uuid4().hex}@example.com"
    password = "Password123!"

    assert (
        register_user(
            client,
            email=first_email,
            password=password,
            full_name="Owner User",
        ).status_code
        == 201
    )
    assert (
        register_user(
            client,
            email=second_email,
            password=password,
            full_name="Other User",
        ).status_code
        == 201
    )

    owner_login = login_user(client, email=first_email, password=password)
    assert owner_login.status_code == 200
    owner_access_token = owner_login.json()["access_token"]

    other_login = login_user(client, email=second_email, password=password)
    assert other_login.status_code == 200
    other_access_token = other_login.json()["access_token"]

    other_session_id = UUID(decode_token(other_access_token)["session_id"])

    forbidden_response = client.delete(
        f"/api/v1/sessions/{other_session_id}",
        headers=auth_header(owner_access_token),
    )
    assert forbidden_response.status_code == 403

    owner_session_id = UUID(decode_token(owner_access_token)["session_id"])
    revoke_response = client.delete(
        f"/api/v1/sessions/{owner_session_id}",
        headers=auth_header(owner_access_token),
    )
    assert revoke_response.status_code == 204

    db_session.expire_all()
    owner_session = db_session.get(UserSession, owner_session_id)
    assert owner_session is not None
    assert owner_session.is_active is False


def test_revoke_other_sessions_keeps_current_session_active(client, db_session):
    email = f"revoke-all-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Revoke All User",
    )
    assert register_response.status_code == 201

    first_login = login_user(client, email=email, password=password)
    assert first_login.status_code == 200
    first_access_token = first_login.json()["access_token"]
    first_session_id = UUID(decode_token(first_access_token)["session_id"])

    second_login = login_user(client, email=email, password=password)
    assert second_login.status_code == 200
    second_access_token = second_login.json()["access_token"]
    second_session_id = UUID(decode_token(second_access_token)["session_id"])

    revoke_response = client.delete(
        "/api/v1/sessions/",
        headers=auth_header(second_access_token),
    )
    assert revoke_response.status_code == 204

    db_session.expire_all()
    first_session = db_session.get(UserSession, first_session_id)
    second_session = db_session.get(UserSession, second_session_id)
    assert first_session is not None
    assert second_session is not None
    assert first_session.is_active is False
    assert second_session.is_active is True
