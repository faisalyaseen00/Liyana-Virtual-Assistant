# AI Services Guide

This document maps every backend file involved in sending an AI chat message.

## Request Flow

`POST /conversations/{conversation_id}/chat`

1. `app/api/v1/chat.py` authenticates the user, validates the request, and calls `ChatService`.
2. `app/services/chat_service.py` loads the latest 20 messages, calls `AIService`, then saves the user and assistant messages.
3. `app/services/ai_service.py` converts database `Message` objects into provider-neutral `LLMMessage` objects.
4. `app/providers/grok.py` sends the messages to the Groq chat-completions API.
5. The response is stored as an assistant message and returned through `ChatResponse`.

## Files To Know

| File | Responsibility |
|---|---|
| `app/api/v1/chat.py` | Public chat endpoint, auth/database wiring, HTTP errors (`502` for provider failure, `404` for missing conversation). |
| `app/api/v1/router.py` | Registers the chat router under the API router. |
| `app/schemas/chat.py` | `ChatRequest` input and `ChatResponse` output DTOs. |
| `app/services/chat_service.py` | Chat orchestration: retrieve history, generate reply, persist both messages. |
| `app/services/ai_service.py` | Provider-independent AI logic and conversion from database messages to LLM messages. |
| `app/providers/base.py` | `LLMMessage` dataclass and abstract `LLMProvider.generate()` contract. |
| `app/providers/grok.py` | Current provider adapter. It uses `AsyncGroq`, `GROQ_API_KEY`, `GROQ_MODEL`, and a 300-token completion limit. |
| `app/providers/__init__.py` | Provider package marker; add exports here only if the package API needs them. |
| `app/core/settings.py` | Loads required `DATABASE_URL`, `SECRET_KEY`, and `GROQ_API_KEY`; defines the default model. |
| `app/dependencies/auth.py` | Resolves the authenticated user used by the chat endpoint. |
| `app/dependencies/db.py` | Provides the SQLAlchemy session passed into `ChatService`. |
| `app/services/message_service.py` | Enforces conversation ownership and creates/reads messages. |
| `app/repositories/message_repository.py` | Database queries for message history and persistence. Recent history is returned oldest-to-newest. |
| `app/repositories/conversation_repository.py` | Verifies conversation ownership and updates `last_message_at`. |
| `app/models/message.py` | Message table: role, content, conversation ID, metadata, and timestamp. |
| `app/models/conversation.py` | Conversation ownership and message relationship. |
| `app/models/enums.py` | Supported roles: `user`, `assistant`, `system`, and `tool`. |
| `app/schemas/message.py` | Serializes persisted user and assistant messages in the chat response. |
| `app/models/user.py` | User record referenced by conversation ownership. |
| `app/main.py` | Includes the API router and loads database models. |
| `app/db/models.py` | Imports models so SQLAlchemy metadata and migrations can discover them. |
| `alembic/versions/c990c250ad0c_add_conversations_and_messages.py` | Creates the conversation and message database tables. |
| `requirements.txt` | Contains FastAPI, SQLAlchemy, Pydantic Settings, and the Groq SDK dependencies. |
| `README.md` | Documents `.env` values and local backend startup. |
| `tests/test_conversation_persistence.py` | Existing persistence smoke test; it is related to message storage but does not test the provider flow. |

## Environment

Create `Backend/.env` with at least:

```env
DATABASE_URL=postgresql+psycopg://user:password@localhost:5432/sentinel
SECRET_KEY=replace-with-a-long-random-secret
GROQ_API_KEY=replace-with-your-groq-key
GROQ_MODEL=llama-3.1-8b-instant
```

## Current Behavior And Decisions

- Only the latest 20 persisted messages are sent as context.
- The pending user message is added to the provider request before it is persisted.
- Messages are persisted only after the provider returns, preventing an orphaned user message on provider failure.
- Conversation ownership is checked before history retrieval and message creation.
- `GrokProvider` is the class name, but the implementation calls Groq. Rename it later if clearer provider naming is desired.
- Provider errors are currently caught broadly by the API endpoint and exposed as a generic `502` response.
- There is no system prompt, streaming response, retry policy, token accounting, provider selection, or dedicated AI-service test yet.

## Recommended Implementation Order

1. Add unit tests for `AIService` message conversion and `ChatService` success/failure paths.
2. Move provider construction behind dependency injection or a provider factory.
3. Add input limits and explicit provider error types before expanding features.
4. Decide whether system prompts, streaming, retries, and response metadata belong in the service contract.
