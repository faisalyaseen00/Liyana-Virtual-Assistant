from uuid import uuid4


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


def test_register_user_success_and_duplicate_email_returns_400(client):
    email = f"register-{uuid4().hex}@example.com"

    first_response = register_user(
        client,
        email=email,
        password="Password123!",
        full_name="Register User",
    )
    assert first_response.status_code == 201
    assert "user_id" in first_response.json()

    duplicate_response = register_user(
        client,
        email=email,
        password="Password123!",
        full_name="Register User",
    )
    assert duplicate_response.status_code == 400


def test_login_success_and_wrong_password_returns_401(client):
    email = f"login-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Login User",
    )
    assert register_response.status_code == 201

    login_response = login_user(
        client,
        email=email,
        password=password,
    )
    assert login_response.status_code == 200
    body = login_response.json()
    assert body["token_type"] == "bearer"
    assert "access_token" in body
    assert "refresh_token" in body

    wrong_password_response = login_user(
        client,
        email=email,
        password="wrong-password",
    )
    assert wrong_password_response.status_code == 401


def test_refresh_access_token_returns_200(client):
    email = f"user-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Refresh User",
    )
    assert register_response.status_code == 201

    login_response = login_user(
        client,
        email=email,
        password=password,
    )
    assert login_response.status_code == 200
    refresh_token = login_response.json()["refresh_token"]

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )

    assert refresh_response.status_code == 200
    body = refresh_response.json()
    assert body["token_type"] == "bearer"
    assert "access_token" in body


def test_refresh_rejected_for_revoked_or_garbage_token(client):
    email = f"refresh-fail-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Refresh Fail User",
    )
    assert register_response.status_code == 201

    login_response = login_user(
        client,
        email=email,
        password=password,
    )
    assert login_response.status_code == 200
    refresh_token = login_response.json()["refresh_token"]

    logout_response = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert logout_response.status_code == 200

    revoked_refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )
    assert revoked_refresh_response.status_code == 401

    garbage_refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": "garbage-token"},
    )
    assert garbage_refresh_response.status_code == 401


def test_logout_is_idempotent(client):
    email = f"logout-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Logout User",
    )
    assert register_response.status_code == 201

    login_response = login_user(
        client,
        email=email,
        password=password,
    )
    assert login_response.status_code == 200
    refresh_token = login_response.json()["refresh_token"]

    first_logout = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert first_logout.status_code == 200

    second_logout = client.post(
        "/api/v1/auth/logout",
        json={"refresh_token": refresh_token},
    )
    assert second_logout.status_code == 200


def test_get_current_user_returns_profile_and_rejects_bad_tokens(client):
    email = f"profile-{uuid4().hex}@example.com"
    password = "Password123!"

    register_response = register_user(
        client,
        email=email,
        password=password,
        full_name="Profile User",
    )
    assert register_response.status_code == 201

    login_response = login_user(
        client,
        email=email,
        password=password,
    )
    assert login_response.status_code == 200
    access_token = login_response.json()["access_token"]

    profile_response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )
    assert profile_response.status_code == 200
    body = profile_response.json()
    assert body["email"] == email
    assert body["full_name"] == "Profile User"

    missing_token_response = client.get("/api/v1/users/me")
    assert missing_token_response.status_code == 401

    invalid_token_response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer invalid-token"},
    )
    assert invalid_token_response.status_code == 401
