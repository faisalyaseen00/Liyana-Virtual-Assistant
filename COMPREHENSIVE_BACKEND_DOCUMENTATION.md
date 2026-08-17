# Sentinel AI - Comprehensive Backend Documentation

**Last Updated:** 2026-08-14  
**Project Status:** Development Phase - Conversation/Chat Features in Progress

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Architecture](#architecture)
3. [Database Schema](#database-schema)
4. [API Endpoints](#api-endpoints)
5. [Core Services](#core-services)
6. [Repository Layer](#repository-layer)
7. [Dependency Injection](#dependency-injection)
8. [Authentication Flow](#authentication-flow)
9. [Conversation & Chat System](#conversation--chat-system)
10. [Provider System](#provider-system)
11. [Current Project State](#current-project-state)
12. [Tech Stack](#tech-stack)

---

## Project Overview

**Sentinel AI** is a multi-platform AI assistant application consisting of:

- **Backend:** FastAPI-based REST API with PostgreSQL database
- **Mobile App:** Flutter application for multi-platform support (iOS, Android, Web, Windows, Linux, macOS)

### Core Purpose

The backend provides:
- User authentication and session management
- Conversation persistence and message storage
- AI-powered chat responses via Grok API
- User profile management
- Multi-device session tracking

---

## Architecture

### Layered Application Structure

```
app/
├── main.py                 # FastAPI app entry point
├── api/v1/                # API Routes (Controller layer)
│   ├── auth.py           # Authentication endpoints
│   ├── users.py          # User profile endpoints
│   ├── session.py        # Session management endpoints
│   ├── conversations.py  # Conversation CRUD endpoints
│   ├── messages.py       # Message endpoints (planned)
│   ├── chat.py           # Chat/messaging endpoints
│   ├── health.py         # Health check
│   └── router.py         # Route aggregator
├── services/              # Business Logic (Service layer)
│   ├── auth_service.py
│   ├── user_service.py
│   ├── session_service.py
│   ├── conversation_service.py
│   ├── message_service.py
│   ├── chat_service.py
│   └── ai_service.py
├── repositories/          # Data Access (Repository layer)
│   ├── user_repository.py
│   ├── session_repository.py
│   ├── conversation_repository.py
│   └── message_repository.py
├── models/               # ORM Models (Entity layer)
│   ├── user.py
│   ├── session.py
│   ├── conversation.py
│   ├── message.py
│   └── enums.py
├── schemas/              # Pydantic Validation Models (DTO layer)
│   ├── auth.py
│   ├── user.py
│   ├── session.py
│   ├── conversation.py
│   ├── message.py
│   └── chat.py
├── dependencies/         # Dependency Injection
│   ├── db.py            # Database session provider
│   ├── auth.py          # Current user & session providers
│   └── session.py
├── core/                 # Core Utilities
│   ├── settings.py       # Configuration management
│   ├── security.py       # Password hashing & token generation
│   └── device.py         # User agent parsing
├── db/                   # Database Configuration
│   ├── session.py        # SQLAlchemy session factory
│   ├── base.py          # ORM base class
│   └── models.py        # Model exports
├── providers/            # LLM Providers
│   ├── base.py          # Abstract provider interface
│   ├── grok.py          # Groq API implementation
│   └── __init__.py
└── utils/                # Utilities
    └── jwt.py            # JWT token handling
```

### Data Flow Pattern

```
Request
  ↓
FastAPI Route (api/v1/*.py)
  ↓
Pydantic Schema Validation
  ↓
Dependency Injection (CurrentUser, CurrentSession, get_db)
  ↓
Service Layer (business logic)
  ↓
Repository Layer (database queries)
  ↓
SQLAlchemy ORM Models
  ↓
PostgreSQL Database
  ↓
Response (Pydantic Schema)
```

---

## Database Schema

### Database Engine

- **Type:** PostgreSQL
- **Connection String:** Configured via `DATABASE_URL` environment variable
- **ORM:** SQLAlchemy 2.0+ with declarative mapping
- **Migrations:** Alembic (version control for schema changes)

### Tables

#### 1. **users** Table

Stores user account information.

```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Authentication
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    
    -- Profile Information
    full_name VARCHAR(255),
    profile_picture VARCHAR(500),
    timezone VARCHAR(100) DEFAULT 'UTC',
    language VARCHAR(50) DEFAULT 'en',
    
    -- Account Status
    is_active BOOLEAN DEFAULT TRUE,
    is_verified BOOLEAN DEFAULT FALSE,
    
    -- Login Information
    last_login_at TIMESTAMP WITH TIME ZONE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX ix_users_email ON users(email);
```

**SQLAlchemy Model:** `app/models/user.py`

**Relationships:**
- Has many `sessions` (cascade delete)
- Has many `conversations` (cascade delete)

---

#### 2. **sessions** Table

Stores user session information for multi-device support and authentication token management.

```sql
CREATE TABLE sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationship
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Authentication
    refresh_token_hash VARCHAR(255) NOT NULL,
    
    -- Device Information
    device_name VARCHAR(255),
    device_type VARCHAR(50),
    browser VARCHAR(100),
    operating_system VARCHAR(100),
    ip_address VARCHAR(45),
    user_agent VARCHAR(500),
    
    -- Session State
    is_active BOOLEAN DEFAULT TRUE,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_activity_at TIMESTAMP WITH TIME ZONE NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    revoked_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_sessions_user_id ON sessions(user_id);
```

**SQLAlchemy Model:** `app/models/session.py`

**Relationships:**
- Belongs to `users` (many-to-one)

**Key Features:**
- Refresh token stored as SHA256 hash for security
- Device information parsed from User-Agent header
- Activity tracking for last interaction timestamp
- Expiration tracking (default: 30 days)
- Soft delete via `revoked_at` timestamp

---

#### 3. **conversations** Table

Stores conversation records (chat threads).

```sql
CREATE TABLE conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationship
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Conversation Information
    title VARCHAR(255) DEFAULT 'New Chat' NOT NULL,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_message_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX ix_conversations_user_id ON conversations(user_id);
```

**SQLAlchemy Model:** `app/models/conversation.py`

**Relationships:**
- Belongs to `users` (many-to-one)
- Has many `messages` (cascade delete)

**Key Features:**
- Each conversation belongs to a specific user
- Title can be auto-generated or user-provided
- Indexed by `last_message_at` for sorting conversations by recency

---

#### 4. **messages** Table

Stores individual messages within conversations.

```sql
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    
    -- Relationship
    conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
    
    -- Message Information
    role ENUM('user', 'assistant', 'system', 'tool') NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB,
    
    -- Audit
    created_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE INDEX ix_messages_conversation_id ON messages(conversation_id);
```

**SQLAlchemy Model:** `app/models/message.py`

**Enums (MessageRole):**
- `USER` - Message from user
- `ASSISTANT` - Response from AI
- `SYSTEM` - System-level messages
- `TOOL` - Tool/function call responses

**Relationships:**
- Belongs to `conversations` (many-to-one)

**Key Features:**
- JSONB metadata column for flexible additional data
- Role-based message classification
- Indexed by conversation for fast retrieval

---

## API Endpoints

### Base URL

```
http://localhost:8000/api/v1
```

### Authentication

All authenticated endpoints require:
- **Header:** `Authorization: Bearer <access_token>`
- **Token Type:** JWT access token (30-minute expiration)

---

### 1. Health Check

#### GET `/health`

Returns API health status.

**Response:**
```json
{
  "status": "healthy",
  "service": "Sentinel AI API",
  "version": "1.0.0",
  "timestamp": "2026-08-14T12:00:00Z"
}
```

---

### 2. Authentication Endpoints

**Prefix:** `/auth`

#### POST `/auth/register`

Register a new user.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123",
  "full_name": "John Doe"
}
```

**Response (201 Created):**
```json
{
  "message": "User registered successfully",
  "user_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Validation:**
- Email: Valid email format, unique in database
- Password: 8-128 characters
- Full name: Optional, max 255 characters

---

#### POST `/auth/login`

Authenticate user and create session.

**Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePassword123"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "refresh_token": "random_urlsafe_token",
  "token_type": "bearer"
}
```

**Process:**
1. Verifies email/password
2. Parses User-Agent to extract device info
3. Creates session record
4. Returns access token (30 min expiry) and refresh token (7 day expiry)
5. Updates user's `last_login_at`

---

#### POST `/auth/refresh`

Exchange refresh token for new access token.

**Request:**
```json
{
  "refresh_token": "random_urlsafe_token"
}
```

**Response:**
```json
{
  "access_token": "eyJhbGc...",
  "token_type": "bearer"
}
```

---

#### POST `/auth/logout`

Revoke current session.

**Request:**
```json
{
  "refresh_token": "random_urlsafe_token"
}
```

**Response:**
```json
{
  "message": "Logged out successfully"
}
```

---

### 3. User Endpoints

**Prefix:** `/users`  
**Authentication:** Required

#### GET `/users/me`

Get authenticated user profile.

**Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "full_name": "John Doe",
  "profile_picture": "https://example.com/pic.jpg",
  "timezone": "UTC",
  "language": "en",
  "is_active": true,
  "is_verified": false
}
```

---

#### PATCH `/users/me`

Update user profile.

**Request:**
```json
{
  "full_name": "Jane Doe",
  "profile_picture": "https://example.com/new_pic.jpg",
  "timezone": "America/New_York",
  "language": "es"
}
```

**Response:** Updated user profile (same format as GET `/users/me`)

---

### 4. Session Endpoints

**Prefix:** `/sessions`  
**Authentication:** Required

#### GET `/sessions/`

List active sessions for current user.

**Response:**
```json
[
  {
    "id": "session-uuid",
    "device_name": "Chrome",
    "browser": "Chrome",
    "operating_system": "Windows",
    "ip_address": "192.168.1.1",
    "created_at": "2026-08-14T10:00:00Z",
    "last_activity_at": "2026-08-14T12:00:00Z",
    "is_current": true
  }
]
```

---

#### DELETE `/sessions/{session_id}`

Revoke specific session (status: 204 No Content).

---

#### DELETE `/sessions/`

Revoke all other sessions except current (status: 204 No Content).

---

### 5. Conversation Endpoints

**Prefix:** `/conversations`  
**Authentication:** Required

#### POST `/conversations`

Create new conversation.

**Response:**
```json
{
  "id": "conversation-uuid",
  "user_id": "user-uuid",
  "title": "New Chat",
  "created_at": "2026-08-14T12:00:00Z",
  "updated_at": "2026-08-14T12:00:00Z",
  "last_message_at": "2026-08-14T12:00:00Z"
}
```

---

#### GET `/conversations`

List all conversations for current user.

**Response:**
```json
[
  {
    "id": "conversation-uuid",
    "user_id": "user-uuid",
    "title": "Project Planning",
    "created_at": "2026-08-14T10:00:00Z",
    "updated_at": "2026-08-14T12:00:00Z",
    "last_message_at": "2026-08-14T12:00:00Z"
  }
]
```

**Note:** Conversations are sorted by `last_message_at` in descending order.

---

#### GET `/conversations/{conversation_id}`

Get specific conversation.

**Response:** Single conversation object (same format as POST response)

**Error Handling:**
- Returns 404 if conversation not found
- Returns 404 if conversation doesn't belong to user

---

### 6. Chat Endpoints

**Prefix:** `/conversations/{conversation_id}/chat`  
**Authentication:** Required

#### POST `/conversations/{conversation_id}/chat`

Send message and get AI response.

**Request:**
```json
{
  "content": "What is machine learning?"
}
```

**Response (201 Created):**
```json
{
  "user_message": {
    "id": "message-uuid",
    "conversation_id": "conversation-uuid",
    "role": "user",
    "content": "What is machine learning?",
    "extra_data": null,
    "created_at": "2026-08-14T12:00:00Z"
  },
  "assistant_message": {
    "id": "message-uuid",
    "conversation_id": "conversation-uuid",
    "role": "assistant",
    "content": "Machine learning is a subset of AI...",
    "extra_data": null,
    "created_at": "2026-08-14T12:00:01Z"
  }
}
```

**Process:**
1. Validates conversation belongs to user
2. Saves user message to database
3. Retrieves last 20 messages for context
4. Calls Grok API (Llama 3.1 8B) for response
5. Saves AI response to database
6. Updates conversation's `last_message_at`
7. Returns both messages

---

## Core Services

### AuthService

**File:** `app/services/auth_service.py`

**Responsibilities:**
- User registration with duplicate email checking
- User login with password verification
- Access token refresh via refresh token
- Session logout/revocation

**Key Methods:**

```python
register_user(db, data: RegisterRequest) -> User
login_user(db, data: LoginRequest, user_agent?, ip_address?) -> TokenResponse
refresh_access_token(db, refresh_token: str) -> dict
logout_user(db, refresh_token: str) -> None
```

---

### ChatService

**File:** `app/services/chat_service.py`

**Responsibilities:**
- Orchestrates message sending and AI response generation
- Manages conversation context retrieval
- Saves both user and assistant messages

**Key Methods:**

```python
async send_message(
    conversation_id: UUID,
    user_id: UUID,
    content: str
) -> tuple[Message, Message] | None
```

**Process:**
1. Save user message
2. Retrieve last 20 messages for context
3. Call AIService to generate response
4. Save assistant message
5. Return both messages

---

### ConversationService

**File:** `app/services/conversation_service.py`

**Responsibilities:**
- Create, read, update, delete conversations
- Retrieve user's conversations
- Update conversation titles

**Key Methods:**

```python
create_conversation(user_id, title?) -> Conversation
get_conversation(conversation_id, user_id) -> Conversation | None
get_user_conversations(user_id) -> list[Conversation]
update_title(conversation_id, user_id, title) -> Conversation | None
delete_conversation(conversation_id, user_id) -> bool
```

---

### MessageService

**File:** `app/services/message_service.py`

**Responsibilities:**
- Create and retrieve messages
- Fetch conversation history
- Get recent messages for context

**Key Methods:**

```python
create_message(
    conversation_id, user_id, role, content, extra_data?
) -> Message | None
get_message(message_id, user_id) -> Message | None
get_conversation_messages(conversation_id, user_id) -> list[Message] | None
get_recent_messages(conversation_id, user_id, limit=20) -> list[Message] | None
```

---

### AIService

**File:** `app/services/ai_service.py`

**Responsibilities:**
- Wrapper around LLM providers
- Converts database messages to provider format
- Calls provider to generate responses

**Key Methods:**

```python
async generate_response(history: list[Message]) -> str
```

---

### UserService

**File:** `app/services/user_service.py`

**Responsibilities:**
- User retrieval and profile updates

**Key Methods:**

```python
get_user_by_id(db, user_id) -> User
update_user(db, user, data: UpdateUserRequest) -> User
```

---

### SessionService

**File:** `app/services/session_service.py`

**Responsibilities:**
- List user sessions
- Revoke sessions
- Revoke other sessions (keep current one active)

**Key Methods:**

```python
get_user_sessions(user, current_session) -> list[SessionResponse]
revoke_session(session_id, user) -> None
revoke_other_sessions(user, current_session) -> None
update_last_activity(session) -> None
```

---

## Repository Layer

### Data Access Pattern

Repositories provide a clean interface between services and database, handling:
- SQL query construction
- Database session management
- Commit/rollback handling
- Object hydration

### UserRepository

**File:** `app/repositories/user_repository.py`

```python
get_by_email(db, email) -> User | None
get_by_id(db, user_id) -> User | None
create(db, email, hashed_password, full_name?) -> User
```

---

### SessionRepository

**File:** `app/repositories/session_repository.py`

```python
create(db, user_id, refresh_token_hash, ...) -> Session
get_by_refresh_token_hash(refresh_token_hash) -> Session | None
get_by_id(session_id) -> Session | None
get_by_user(user_id) -> list[Session]
revoke(session) -> None
revoke_all_except(user_id, current_session_id) -> None
update_activity(session) -> None
```

---

### ConversationRepository

**File:** `app/repositories/conversation_repository.py`

```python
create(user_id, title?) -> Conversation
get_by_id(conversation_id) -> Conversation | None
get_by_id_for_user(conversation_id, user_id) -> Conversation | None
get_by_user(user_id) -> list[Conversation]
update_last_message_at(conversation) -> None
update_title(conversation, title) -> None
delete(conversation) -> None
```

---

### MessageRepository

**File:** `app/repositories/message_repository.py`

```python
create(conversation_id, role, content, extra_data?) -> Message
get_by_id(message_id) -> Message | None
get_by_conversation(conversation_id) -> list[Message]
get_recent_by_conversation(conversation_id, limit=20) -> list[Message]
```

---

## Dependency Injection

### Database Session

**File:** `app/dependencies/db.py`

```python
def get_db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

Creates a new database session for each request and closes it afterward.

---

### Current User

**File:** `app/dependencies/auth.py`

```python
def get_current_user(
    credentials: HTTPAuthorizationCredentials,
    db: Session
) -> User:
    # 1. Extract token from Authorization header
    # 2. Decode JWT
    # 3. Verify token type is "access"
    # 4. Load user by subject claim
    # 5. Verify user is active
    # 6. Return user object
```

**Usage:**
```python
@router.get("/me")
def get_profile(current_user: CurrentUser):
    return current_user
```

**Type Alias:**
```python
CurrentUser = Annotated[User, Depends(get_current_user)]
```

---

### Current Session

**File:** `app/dependencies/session.py`

```python
def get_current_session(
    credentials: HTTPAuthorizationCredentials,
    db: Session
) -> UserSession:
    # 1. Extract token
    # 2. Decode JWT
    # 3. Extract session_id from payload
    # 4. Load session from database
    # 5. Verify session is active
    # 6. Update last_activity_at
    # 7. Return session object
```

**Usage:**
```python
@router.get("/")
def get_sessions(
    current_user: CurrentUser,
    current_session: CurrentSession
):
    pass
```

**Type Alias:**
```python
CurrentSession = Annotated[UserSession, Depends(get_current_session)]
```

---

## Authentication Flow

### Registration Flow

```
1. Client POST /api/v1/auth/register
   ↓ (email, password, full_name)
2. Validate Pydantic schema
3. Check if email already exists
4. Hash password using pwdlib
5. Create user in database
6. Return user_id
```

---

### Login Flow

```
1. Client POST /api/v1/auth/login
   ↓ (email, password, User-Agent header)
2. Verify email/password
3. Parse User-Agent for device info
4. Generate refresh token (60 char urlsafe)
5. Hash refresh token (SHA256)
6. Create session record in database
7. Create JWT access token:
   {
     "sub": user_id (string),
     "session_id": session_id (string),
     "type": "access",
     "exp": now + 30 minutes
   }
8. Return access_token + refresh_token
```

---

### Authenticated Request Flow

```
1. Client sends: Authorization: Bearer <access_token>
   ↓
2. HTTPBearer security scheme extracts token
   ↓
3. decode_token() verifies JWT signature
   ↓
4. Validate token type == "access"
   ↓
5. Load user by "sub" claim (user_id)
   ↓
6. Verify user.is_active == true
   ↓
7. Return User object to route
   ↓
8. Route accesses current_user.id, etc.
```

---

### Token Refresh Flow

```
1. Client POST /api/v1/auth/refresh
   ↓ (refresh_token)
2. Hash refresh token
3. Find session by refresh_token_hash
4. Verify session is active
5. Verify session hasn't expired
6. Load user
7. Update session.last_activity_at
8. Create new access token
9. Return new access_token
```

---

## Conversation & Chat System

### Conversation Model

A conversation is a thread of messages between a user and the AI assistant.

**Properties:**
- `id` - Unique identifier (UUID)
- `user_id` - Owner of conversation
- `title` - Conversation title (default: "New Chat")
- `created_at` - Conversation creation time
- `updated_at` - Last update time
- `last_message_at` - Timestamp of last message

**Relationships:**
- Owns many `messages`

---

### Message Model

Individual message within a conversation.

**Properties:**
- `id` - Unique identifier (UUID)
- `conversation_id` - Parent conversation
- `role` - Message source (user/assistant/system/tool)
- `content` - Message text (TEXT field, no size limit)
- `extra_data` - JSONB metadata (optional)
- `created_at` - Message creation time

**Message Roles:**
- `user` - User input
- `assistant` - AI response
- `system` - System-generated (e.g., context, instructions)
- `tool` - Function/tool call response

---

### Chat Workflow

```
1. Client sends message via POST /conversations/{id}/chat
   ↓
2. ChatService.send_message() called
   ↓
3. Save user message to database
   ↓
4. Retrieve last 20 messages (conversation history)
   ↓
5. Convert Message objects to LLMMessage format
   ↓
6. Call AIService.generate_response()
   ↓
7. AIService calls GrokProvider.generate()
   ↓
8. Grok API returns assistant response
   ↓
9. Save assistant message to database
   ↓
10. Update conversation.last_message_at
    ↓
11. Return both messages to client
```

---

## Provider System

### LLM Provider Architecture

**Abstract Base:** `app/providers/base.py`

```python
class LLMProvider(ABC):
    @abstractmethod
    async def generate(self, messages: list[LLMMessage]) -> str:
        pass

@dataclass
class LLMMessage:
    role: str
    content: str
```

### Grok Provider

**File:** `app/providers/grok.py`

**Implementation:** Groq async client wrapper

```python
class GrokProvider(LLMProvider):
    def __init__(self):
        self.client = AsyncGroq(api_key=settings.groq_api_key)
    
    async def generate(self, messages: list[LLMMessage]) -> str:
        # Convert LLMMessage to Groq format
        # Call llama-3.1-8b-instant model
        # Return response content
```

**Configuration:**
- **Model:** `llama-3.1-8b-instant`
- **Max Tokens:** 300
- **API Key:** From `GROQ_API_KEY` environment variable

---

## Core Utilities

### Settings Configuration

**File:** `app/core/settings.py`

```python
class Settings(BaseSettings):
    # Application
    app_name: str = "Sentinel AI"
    app_env: str = "development"
    debug: bool = True
    
    # Database
    database_url: str  # e.g., postgresql://user:pass@localhost/db
    
    # Security
    secret_key: str  # For JWT signing
    algorithm: str = "HS256"
    
    # Token Expiration
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    
    # Grok API
    groq_api_key: str
```

**Loading:** From `.env` file via Pydantic Settings

---

### Security Functions

**File:** `app/core/security.py`

```python
hash_password(password: str) -> str
# Uses pwdlib for secure password hashing

verify_password(password: str, hashed_password: str) -> bool
# Verifies password against stored hash

generate_refresh_token() -> str
# Generates 60-character cryptographically secure token

hash_refresh_token(token: str) -> str
# SHA256 hash of refresh token before storage
```

---

### JWT Functions

**File:** `app/utils/jwt.py`

```python
create_access_token(user_id: UUID, session_id: UUID) -> str
# Creates JWT with:
# - sub: user_id
# - session_id: session_id
# - type: "access"
# - exp: now + 30 minutes

decode_token(token: str) -> dict
# Decodes JWT, returns payload or empty dict if invalid
```

---

### Device Parsing

**File:** `app/core/device.py`

```python
parse_user_agent(user_agent: str | None) -> dict
# Extracts from User-Agent header:
# - device_name (e.g., "Chrome")
# - device_type ("Mobile", "Tablet", "Desktop", "Unknown")
# - browser (e.g., "Chrome", "Safari")
# - operating_system (e.g., "Windows", "iOS")
```

---

## Current Project State

### Completed Features

✅ **Authentication System**
- Registration with email uniqueness validation
- Login with password verification
- Multi-device session management
- Token refresh mechanism
- Logout/session revocation

✅ **User Profile Management**
- User profile retrieval
- Profile updates (name, picture, timezone, language)
- User account status tracking

✅ **Session Management**
- Multi-session per user support
- Device information tracking
- Activity tracking
- Session revocation (single or all except current)

✅ **Conversation System**
- Create conversations
- List user conversations (sorted by recency)
- Retrieve individual conversations
- Ownership validation

✅ **Chat System**
- Send messages to conversations
- AI response generation via Grok API
- Message persistence
- Conversation context (last 20 messages)
- Real-time response retrieval

✅ **Database**
- PostgreSQL integration
- SQLAlchemy ORM models
- Alembic migrations
- Relationships and cascading deletes

### In Progress / Planned

⏳ **Message Management API**
- Get messages in conversation
- Delete messages
- Edit messages

⏳ **Conversation Management**
- Update conversation title
- Delete conversation
- Search conversations

⏳ **Mobile App Integration**
- Flutter app connection
- Real-time updates (WebSocket?)
- Offline sync

⏳ **Additional Features**
- Typing indicators
- Message reactions
- Conversation sharing
- Multi-user conversations
- File upload support
- Context window optimization

---

## Tech Stack

### Backend

| Component | Technology | Version |
|-----------|-----------|---------|
| Framework | FastAPI | Latest |
| Server | Uvicorn | ASGI server |
| Database | PostgreSQL | Configured |
| ORM | SQLAlchemy | 2.0+ |
| Migrations | Alembic | Latest |
| Validation | Pydantic | V2 |
| Authentication | PyJWT | Latest |
| Password Hashing | pwdlib | Latest |
| User Agent Parsing | user-agents | Latest |
| LLM Provider | Groq SDK | Latest |
| Async | asyncio | Python 3.9+ |

### Environment Requirements

```
Python 3.9+
PostgreSQL 12+
```

### Run Command

```bash
cd Backend
python -m uvicorn app.main:app --reload
```

---

## Configuration

### Required Environment Variables

```.env
# Database
DATABASE_URL=postgresql://user:password@localhost:5432/sentinel_ai

# Security
SECRET_KEY=your-super-secret-key-here

# API Keys
GROQ_API_KEY=your-groq-api-key

# Optional
APP_ENV=development
DEBUG=true
```

---

## Error Handling

### HTTP Status Codes

- **200 OK** - Successful GET request
- **201 Created** - Successful POST request
- **204 No Content** - Successful DELETE request
- **400 Bad Request** - Validation error
- **401 Unauthorized** - Invalid/missing token
- **403 Forbidden** - Permission denied
- **404 Not Found** - Resource not found
- **500 Internal Server Error** - Server error

### Error Response Format

```json
{
  "detail": "Error message describing what went wrong"
}
```

---

## Database Migrations

### Current Migrations

Located in `Backend/alembic/versions/`:

1. **c80a3b048e36_initial_schema.py** - Initial users/sessions tables
2. **c990c250ad0c_add_conversations_and_messages.py** - Conversation/message tables
3. **f1e70b12b21b_add_user_profile_fields.py** - User profile fields
4. **49b4785bda61_enhance_session_model.py** - Session enhancements
5. **2b1d5c032ca7_enhance_session_model.py** - Additional session fields

### Running Migrations

```bash
cd Backend
alembic upgrade head  # Apply all migrations
alembic downgrade -1  # Rollback one migration
alembic stamp head    # Mark as current without applying
```

---

## Testing

### Current Test Coverage

Located in `Backend/tests/`:

- `test_health.py` - Health endpoint
- `test_auth_refresh.py` - Token refresh logic
- `test_sessions.py` - Session management
- `test_conversation_persistence.py` - Conversation storage

### Running Tests

```bash
cd Backend
pytest
pytest -v  # Verbose output
pytest --cov  # Coverage report
```

---

## CORS Configuration

Currently configured for development (all origins allowed):

```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ⚠️ Change for production
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

**Production Configuration Needed:**

```python
allow_origins=[
    "https://yourdomain.com",
    "https://app.yourdomain.com"
],
allow_credentials=True,
allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
allow_headers=["authorization", "content-type"],
```

---

## Performance Considerations

### Database Indexes

- `users.email` - Unique index for login lookups
- `sessions.user_id` - For session retrieval by user
- `conversations.user_id` - For conversation listing
- `messages.conversation_id` - For message retrieval

### Query Optimizations

- **Message History:** Limited to 20 messages for context (configurable)
- **Conversation Listing:** Indexed by `last_message_at` for efficient sorting
- **Session Retrieval:** Indexed lookups with early filtering

### Connection Pooling

SQLAlchemy session factory configured with:
- `autocommit=False` - Explicit commit control
- `autoflush=False` - Manual flush control
- Pool pre-ping enabled for stale connection detection

---

## Security Best Practices

✅ **Implemented:**
- Password hashing with pwdlib (OWASP-compliant)
- JWT tokens with expiration
- Refresh token hashing before storage
- HTTPS-ready (for production deployment)
- SQL injection protection via SQLAlchemy ORM
- User-input validation with Pydantic

⚠️ **TODO for Production:**
- Enable HTTPS/TLS
- Restrict CORS origins
- Add rate limiting
- Add request logging/auditing
- Implement CSRF protection
- Add secrets management
- Enable SQL query logging in dev only
- Add security headers
- Implement request size limits

---

## Next Steps for Development

1. **Complete Message API**
   - GET /conversations/{id}/messages
   - DELETE /messages/{id}
   - PUT /messages/{id}

2. **Improve Chat System**
   - System prompt management
   - Token counting for context window
   - Message streaming (Server-Sent Events)
   - Rate limiting per user

3. **Mobile App Integration**
   - Wire Flutter app to backend APIs
   - Implement local caching
   - Add offline support
   - Implement WebSocket for real-time updates

4. **Production Readiness**
   - Docker containerization
   - CI/CD pipeline
   - Monitoring and logging
   - Database backup strategy
   - Load testing

5. **Enhanced Features**
   - Conversation search
   - Message reactions
   - File attachments
   - Voice messages
   - Typing indicators

---

## Summary

The Sentinel AI backend is a well-structured FastAPI application implementing:

- **Layered architecture** with clear separation of concerns
- **Multi-device authentication** with session management
- **Conversation-based chat system** with AI responses via Grok
- **PostgreSQL persistence** with SQLAlchemy ORM
- **RESTful API** with proper error handling
- **JWT-based security** with token refresh mechanism

The current implementation provides a solid foundation for the Flutter mobile app and can be extended with additional features as requirements evolve.

