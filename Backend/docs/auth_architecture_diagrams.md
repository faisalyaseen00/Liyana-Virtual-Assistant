# Auth Architecture Diagrams

This file contains copy-pasteable Mermaid code for the authentication architecture described for the current backend.

## 1. High-level architecture

```mermaid
flowchart LR
    Client[Client / Mobile App / Web App] -->|POST /auth/register| AuthAPI[Auth Router]
    Client -->|POST /auth/login| AuthAPI
    Client -->|POST /auth/refresh| AuthAPI
    Client -->|POST /auth/logout| AuthAPI

    AuthAPI --> AuthService[AuthService]

    AuthService --> UserRepo[UserRepository]
    AuthService --> SessionRepo[SessionRepository]

    UserRepo --> Users[(users table)]
    SessionRepo --> Sessions[(sessions table)]

    AuthService --> Security[password hash + refresh token hash]
    AuthService --> JWT[JWT access token helper]
    AuthService --> Device[User-Agent parser]
```

## 2. Register flow

```mermaid
sequenceDiagram
    actor Client
    participant API as Auth Router
    participant Svc as AuthService
    participant URepo as UserRepository
    participant DB as users table
    participant Sec as Security

    Client->>API: email, password, full_name
    API->>Svc: register_user()
    Svc->>URepo: get_by_email(email)
    URepo->>DB: lookup user
    DB-->>URepo: existing_user / none

    alt email already exists
        Svc-->>API: ValueError
        API-->>Client: 400 Email already registered
    else new email
        Svc->>Sec: hash_password(password)
        Svc->>URepo: create(user data)
        URepo->>DB: insert user
        DB-->>URepo: saved user
        API-->>Client: 201 user_id + message
    end
```

## 3. Login flow

```mermaid
sequenceDiagram
    actor Client
    participant API as Auth Router
    participant Svc as AuthService
    participant URepo as UserRepository
    participant Sec as Security
    participant Dev as Device Parser
    participant SRepo as SessionRepository
    participant DB as sessions table
    participant JWT as JWT Helper

    Client->>API: email, password, User-Agent
    API->>Svc: login_user()
    Svc->>URepo: get_by_email(email)
    URepo->>DB: lookup user
    DB-->>URepo: user / none

    alt invalid user
        Svc-->>API: ValueError
        API-->>Client: 401 invalid email or password
    else user found
        Svc->>Sec: verify_password(password, hashed_password)
        alt wrong password
            Svc-->>API: ValueError
            API-->>Client: 401 invalid email or password
        else password valid
            Svc->>Dev: parse_user_agent(User-Agent)
            Svc->>Sec: generate_refresh_token()
            Svc->>Sec: hash_refresh_token(refresh_token)
            Svc->>SRepo: create(session)
            SRepo->>DB: insert session row
            DB-->>SRepo: saved session with session_id
            Svc->>JWT: create_access_token(user_id, session_id)
            API-->>Client: access_token + refresh_token
        end
    end
```

## 4. Refresh flow

```mermaid
sequenceDiagram
    actor Client
    participant API as Auth Router
    participant Svc as AuthService
    participant Sec as Security
    participant SRepo as SessionRepository
    participant URepo as UserRepository
    participant DB as sessions/users tables
    participant JWT as JWT Helper

    Client->>API: refresh_token
    API->>Svc: refresh_access_token()
    Svc->>Sec: hash_refresh_token(refresh_token)
    Svc->>SRepo: get_by_refresh_token_hash(hash)
    SRepo->>DB: find session by hash
    DB-->>SRepo: session / none

    alt session missing
        Svc-->>API: ValueError
        API-->>Client: 401 invalid refresh token
    else session found
        alt session revoked
            Svc-->>API: ValueError
            API-->>Client: 401 session revoked
        else expired
            Svc-->>API: ValueError
            API-->>Client: 401 refresh token expired
        else valid
            Svc->>URepo: get_by_id(user_id)
            URepo->>DB: lookup user
            DB-->>URepo: user / none
            Svc->>SRepo: update_activity(session)
            Svc->>JWT: create_access_token(user_id, session_id)
            API-->>Client: new access_token + token_type=bearer
        end
    end
```

## 5. Logout flow

```mermaid
sequenceDiagram
    actor Client
    participant API as Auth Router
    participant Svc as AuthService
    participant Sec as Security
    participant SRepo as SessionRepository
    participant DB as sessions table

    Client->>API: refresh_token
    API->>Svc: logout_user()
    Svc->>Sec: hash_refresh_token(refresh_token)
    Svc->>SRepo: get_by_refresh_token_hash(hash)
    SRepo->>DB: find session by hash
    DB-->>SRepo: session / none

    alt session missing
        Svc-->>API: ValueError
        API-->>Client: 401 invalid refresh token
    else already revoked
        Svc-->>API: success no-op
        API-->>Client: 200 Logged out successfully
    else active session
        Svc->>SRepo: revoke(session)
        SRepo->>DB: set is_active=false, revoked_at=now
        API-->>Client: 200 Logged out successfully
    end
```

## 6. Protected request flow

```mermaid
flowchart LR
    Client[Client] -->|Authorization: Bearer access_token| ProtectedAPI[Protected endpoint]
    ProtectedAPI --> CurrentUserDep[get_current_user]
    CurrentUserDep --> JWT[decode JWT]
    JWT --> UserDB[(users table)]
    CurrentUserDep -->|if access token valid and user active| Handler[endpoint handler]
```

## 7. Box layout for Excalidraw

```mermaid
flowchart TB
    subgraph ClientSide[Client Side]
        Client[Client]
    end

    subgraph APILayer[FastAPI API Layer]
        AuthRouter[Auth Router]
        ProtectedAPI[Protected API endpoints]
        CurrentUserDep[Current User dependency]
    end

    subgraph ServiceLayer[Service Layer]
        AuthService[AuthService]
    end

    subgraph RepoLayer[Repository Layer]
        UserRepo[UserRepository]
        SessionRepo[SessionRepository]
    end

    subgraph CoreLayer[Core / Utility Layer]
        PasswordHash[Password hashing]
        RefreshHash[Refresh token hashing]
        JWTAccess[JWT access token helper]
        DeviceParser[User-Agent parser]
    end

    subgraph DatabaseLayer[Database Layer]
        Users[(users table)]
        Sessions[(sessions table)]
    end

    Client --> AuthRouter
    Client --> ProtectedAPI

    AuthRouter --> AuthService
    AuthService --> UserRepo
    AuthService --> SessionRepo
    AuthService --> PasswordHash
    AuthService --> RefreshHash
    AuthService --> JWTAccess
    AuthService --> DeviceParser

    UserRepo --> Users
    SessionRepo --> Sessions

    ProtectedAPI --> CurrentUserDep
    CurrentUserDep --> JWTAccess
    CurrentUserDep --> Users
```

## 8. Quick summary of the real auth design

```mermaid
flowchart LR
    AccessToken[Access token = JWT] --> Stateless[Stateless API authentication]
    RefreshToken[Refresh token = opaque string] --> Stateful[Stateful session control]
    Stateful --> Sessions[(sessions table)]
    Stateless --> Users[(users table)]
```
