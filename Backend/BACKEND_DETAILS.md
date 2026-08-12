# Backend Details

This document describes the current state of the backend in `Backend/` and explains what is implemented, how the logic flows, and which parts are currently available for use.

## 1. High-level summary

The backend is a FastAPI application named Sentinel AI API. It is structured in a layered style:

- API layer: request/response routes under `app/api/v1/`
- Dependency layer: auth, DB session, and session retrieval helpers under `app/dependencies/`
- Service layer: business logic under `app/services/`
- Repository layer: database access helpers under `app/repositories/`
- Data models: SQLAlchemy ORM models under `app/models/`
- Schemas: Pydantic request and response models under `app/schemas/`
- Core utilities: settings, password hashing, JWT handling, and device parsing under `app/core/` and `app/utils/`

The backend currently focuses on authentication, user profile management, and session management.

## 2. Current runtime stack

The backend uses:

- FastAPI for the web framework
- Uvicorn for the ASGI server
- SQLAlchemy for ORM and database access
- Alembic for schema migrations
- Pydantic and Pydantic Settings for validation and configuration
- PostgreSQL-oriented UUID types in the models and migrations
- PyJWT for token encoding and decoding
- pwdlib for password hashing and verification
- user-agents for parsing browser and device information

## 3. How the backend starts

The checked-in run instruction in `Backend/README.md` is:

`e:/Virtual_Assistant/.venv/Scripts/python.exe -m uvicorn app.main:app --reload`

The application entry point is `app/main.py`. It creates the FastAPI app, adds CORS middleware, includes the versioned API router, and exposes a root health-style message at `/`.

## 4. Application entry point

File: `app/main.py`

What it does:

- Creates the FastAPI app with the title Sentinel AI API and version 1.0.0
- Adds CORS middleware with open development settings
- Mounts the API router from `app/api/v1/router.py`
- Defines a simple root route at `/`

Current root response:

- `GET /` returns `{ "message": " AI Backend Running" }`

## 5. API surface currently implemented

All routes are mounted under `/api/v1`.

### 5.1 Health

File: `app/api/v1/health.py`

Route:

- `GET /api/v1/health`

Behavior:

- Returns `status: healthy`
- Returns service name and version
- Returns a UTC timestamp

### 5.2 Authentication

File: `app/api/v1/auth.py`

Routes:

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `POST /api/v1/auth/refresh`
- `POST /api/v1/auth/logout`

Behavior:

- Register creates a new user after checking email uniqueness
- Login verifies email and password, creates a new session, and returns tokens
- Refresh exchanges a refresh token for a new access token
- Logout revokes the session identified by the refresh token

### 5.3 Users

File: `app/api/v1/users.py`

Routes:

- `GET /api/v1/users/me`
- `PATCH /api/v1/users/me`

Behavior:

- `GET /me` returns the authenticated user profile
- `PATCH /me` updates profile fields on the authenticated user

### 5.4 Sessions

File: `app/api/v1/session.py`

Routes:

- `GET /api/v1/sessions/`
- `DELETE /api/v1/sessions/{session_id}`
- `DELETE /api/v1/sessions/`

Behavior:

- Lists active sessions for the current user
- Revokes one selected session
- Revokes all other sessions except the current one

## 6. Request and auth flow

### 6.1 Request pipeline

The request flow is generally:

1. FastAPI route receives the request.
2. Pydantic schema validates the body.
3. Dependency functions resolve the database session and authenticated user/session.
4. Service layer performs business rules.
5. Repository layer performs database queries and updates.
6. SQLAlchemy commits changes and returns ORM objects.

### 6.2 Database session dependency

File: `app/dependencies/db.py`

`get_db()` opens a SQLAlchemy session from `SessionLocal`, yields it to the request, and closes it after the request finishes.

### 6.3 Current user dependency

File: `app/dependencies/auth.py`

`get_current_user()`:

- Reads the bearer token from the Authorization header
- Decodes the JWT
- Requires the token type to be `access`
- Loads the user by the `sub` claim
- Rejects missing, invalid, deleted, or inactive users

The exported alias `CurrentUser` is used in route signatures to reduce repetition.

### 6.4 Current session dependency

File: `app/dependencies/session.py`

`get_current_session()`:

- Reads the bearer token
- Decodes the JWT
- Requires token type to be `access`
- Requires `session_id` to exist in the token payload
- Loads the session from the database
- Rejects missing, revoked, or inactive sessions
- Updates the session activity timestamp after successful validation

The exported alias `CurrentSession` is used in route signatures.

## 7. Authentication logic

### 7.1 Registration

File: `app/services/auth_service.py`

`AuthService.register_user()`:

- Checks whether the email already exists using `UserRepository.get_by_email()`
- Hashes the password using `hash_password()`
- Creates the user through `UserRepository.create()`

Current behavior:

- Emails are normalized to lowercase before storage
- Duplicate registration raises a `ValueError`

### 7.2 Login

`AuthService.login_user()`:

- Finds the user by email
- Verifies the password against the stored hash
- Parses the user agent into device information
- Generates a random refresh token
- Hashes the refresh token before storing it in the database
- Creates a new session record
- Generates a JWT access token containing the user ID and session ID
- Returns both the access token and the raw refresh token

Important implementation detail:

- The refresh token is currently a random secure string, not a JWT.
- The access token is a JWT.
- The refresh token hash is what is stored in the database.

### 7.3 Refresh token exchange

`AuthService.refresh_access_token()` is intended to:

- Hash the submitted refresh token
- Find the corresponding session
- Reject revoked or expired sessions
- Ensure the user still exists
- Refresh the session activity timestamp
- Issue a new access token

### 7.4 Logout

`AuthService.logout_user()` is intended to:

- Hash the submitted refresh token
- Find the corresponding session
- Ignore repeated logout on already revoked sessions
- Revoke the session

## 8. User profile logic

### 8.1 Get current profile

Route:

- `GET /api/v1/users/me`

Behavior:

- Returns the authenticated user object
- Response serialization uses the `UserResponse` schema

### 8.2 Update profile

Route:

- `PATCH /api/v1/users/me`

Behavior:

- Uses `UpdateUserRequest` to accept partial updates
- Applies only provided fields
- Commits and refreshes the updated user

Allowed update fields:

- `full_name`
- `profile_picture`
- `timezone`
- `language`

## 9. Session management logic

### 9.1 List sessions

Route:

- `GET /api/v1/sessions/`

Behavior:

- Returns the active sessions for the authenticated user
- Marks the session represented by the current access token as `is_current = true`

### 9.2 Revoke a single session

Route:

- `DELETE /api/v1/sessions/{session_id}`

Behavior:

- Looks up the session by ID
- Returns 404 if the session does not exist
- Returns 403 if the session belongs to another user
- Marks the session inactive and sets revoked timestamps

### 9.3 Revoke all other sessions

Route:

- `DELETE /api/v1/sessions/`

Behavior:

- Revokes all active sessions for the current user except the current session

## 10. Database models and schema

### 10.1 User model

File: `app/models/user.py`

Stored fields:

- `id`
- `email`
- `hashed_password`
- `full_name`
- `profile_picture`
- `timezone`
- `language`
- `is_active`
- `is_verified`
- `last_login_at`
- `created_at`
- `updated_at`

Relationship:

- A user has many sessions

### 10.2 Session model

File: `app/models/session.py`

Stored fields:

- `id`
- `user_id`
- `refresh_token_hash`
- `device_name`
- `device_type`
- `browser`
- `operating_system`
- `ip_address`
- `user_agent`
- `is_active`
- `created_at`
- `updated_at`
- `last_activity_at`
- `expires_at`
- `revoked_at`

Relationship:

- A session belongs to one user

### 10.3 Migrations

The Alembic history shows the current schema evolution:

- Initial schema created `users` and the first `sessions` table
- User profile fields were added later: `profile_picture`, `timezone`, `language`, and `last_login_at`
- Session tracking was enhanced to store device metadata, `is_active`, `updated_at`, and `last_activity_at`
- The session model was further refined by replacing older fields like `device_info` and `last_used_at` with the newer structure

## 11. Repository layer

### 11.1 User repository

File: `app/repositories/user_repository.py`

Responsibilities:

- Find user by email
- Find user by ID
- Create a new user record

Implementation notes:

- Email lookup normalizes to lowercase
- Create commits immediately and refreshes the ORM object

### 11.2 Session repository

File: `app/repositories/session_repository.py`

Responsibilities:

- Create a session record with device metadata
- Load a session by refresh token hash
- Load a session by ID
- Load all active sessions for a user
- Revoke one session
- Revoke all sessions except the current one
- Update session activity timestamps

## 12. Utility layer

### 12.1 Password and refresh token helpers

File: `app/core/security.py`

Functions:

- `hash_password()` hashes plaintext passwords using pwdlib
- `verify_password()` checks a password against its hash
- `generate_refresh_token()` produces a cryptographically secure random token
- `hash_refresh_token()` stores only a SHA-256 hash of the refresh token

### 12.2 JWT helpers

File: `app/utils/jwt.py`

Functions:

- `create_access_token()` creates a JWT with `sub`, `session_id`, `type=access`, and expiration
- `create_refresh_token()` creates a JWT refresh token with `type=refresh`
- `decode_token()` returns the decoded payload or an empty dict if invalid

Current note:

- The code currently generates random refresh strings in login flow instead of using the JWT refresh-token helper.

### 12.3 Device parsing

File: `app/core/device.py`

Function:

- `parse_user_agent()` converts the raw User-Agent string into device metadata

Returned values:

- `device_name`
- `device_type`
- `browser`
- `operating_system`

If no User-Agent is provided, the function returns safe fallback values such as Unknown Device and Unknown.

## 13. Configuration

File: `app/core/settings.py`

Configuration values:

- `app_name`
- `app_env`
- `debug`
- `database_url`
- `secret_key`
- `algorithm`
- `access_token_expire_minutes`
- `refresh_token_expire_days`

Settings are loaded from `.env` with case-insensitive environment lookup.

The example environment file currently contains:

- `APP_NAME=Sentinel AI`
- `APP_ENV=development`
- `DEBUG=true`

## 14. Validation and error handling

The backend uses a simple service-level pattern:

- Services raise `ValueError` for business-rule failures such as invalid credentials or duplicate registration
- Routes catch those errors and convert them into HTTP responses
- Authentication and session dependencies raise `HTTPException` directly for token or session failures

Common HTTP responses:

- 400 for duplicate registration and some user updates
- 401 for invalid login, invalid tokens, or revoked sessions
- 403 for forbidden session revocation or disabled user accounts
- 404 for missing sessions

## 15. What is currently working

Based on the code currently present, the implemented backend features are:

- FastAPI application startup and routing
- CORS middleware for development
- Health endpoint
- User registration
- User login
- Bearer-token based current-user lookup
- Bearer-token based current-session lookup
- User profile fetch and update
- Session listing
- Session revocation
- Revoke-other-sessions flow
- SQLAlchemy ORM models for users and sessions
- Alembic migrations for the current schema
- Password hashing and verification
- Refresh-token hashing
- User-agent parsing for device metadata

## 16. Important caveats in the current code

The codebase is organized and mostly complete for auth/session/user management, but there are a few implementation inconsistencies worth knowing about:

- `AuthService.refresh_access_token()` and `AuthService.logout_user()` call some repository methods as if they were static methods, while the repository defines them as instance methods.
- `AuthService.refresh_access_token()` references `SessionRepository.update_last_used()`, but the repository method is named `update_activity()`.
- `AuthService.login_user()` returns a random refresh token string, while `app/utils/jwt.py` also contains a JWT-based refresh-token helper that is currently unused.
- `app/core/config.py` is empty.
- There are no checked-in test files under `Backend/tests/`.

Those caveats do not change the architectural intent of the backend, but they matter if you want to run the refresh/logout paths exactly as written.

## 17. Quick file map

- App bootstrap: `app/main.py`
- Router aggregation: `app/api/v1/router.py`
- Health endpoint: `app/api/v1/health.py`
- Authentication routes: `app/api/v1/auth.py`
- User routes: `app/api/v1/users.py`
- Session routes: `app/api/v1/session.py`
- Auth dependency: `app/dependencies/auth.py`
- Current session dependency: `app/dependencies/session.py`
- DB session dependency: `app/dependencies/db.py`
- User ORM model: `app/models/user.py`
- Session ORM model: `app/models/session.py`
- User repository: `app/repositories/user_repository.py`
- Session repository: `app/repositories/session_repository.py`
- Auth service: `app/services/auth_service.py`
- User service: `app/services/user_service.py`
- Session service: `app/services/session_service.py`
- Auth schemas: `app/schemas/auth.py`
- User schemas: `app/schemas/user.py`
- Session schemas: `app/schemas/session.py`
- JWT helpers: `app/utils/jwt.py`
- Password helpers: `app/core/security.py`
- Device parsing: `app/core/device.py`
- Settings: `app/core/settings.py`

## 18. Short summary

The backend is a FastAPI API with implemented authentication, user profile, and session management flows built on SQLAlchemy and Alembic. The code already defines the main data models, routes, services, and migrations, and the main request path is straightforward. The main thing to keep in mind is that a few refresh/logout method calls are inconsistent in the current code, so the document should be treated as a current-state map of the backend rather than a claim that every path is production-hardened.