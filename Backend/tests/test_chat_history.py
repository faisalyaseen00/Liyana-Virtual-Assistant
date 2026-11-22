from uuid import uuid4

import pytest

from app.models.conversation import DEFAULT_TITLE
from app.models.enums import MessageRole
from app.providers.base import LLMMessage, LLMProvider
from app.repositories.message_repository import MessageRepository
from app.repositories.user_repository import UserRepository
from app.services.chat_service import ChatService
from app.services.conversation_service import ConversationService, title_from_message
from tests.test_sessions import auth_header, login_user, register_user


class ChattyProvider(LLMProvider):
    async def generate(self, messages: list[LLMMessage]) -> str:
        if "Semantic Router" in messages[0].content:
            return '{"route":"conversation"}'
        return "Happy to help."


@pytest.mark.parametrize(
    ("message", "title"),
    [
        ("hello there", "Hello there"),
        ("can you explain how black holes form in detail", "Can you explain how black holes…"),
        ("   what's   the weather?  ", "What's the weather"),
        ("x" * 100, "X" + "x" * 59 + "…"),
        ("   ", DEFAULT_TITLE),
    ],
)
def test_title_from_message(message, title):
    assert title_from_message(message) == title


def _user_and_conversation(db):
    user = UserRepository.create(
        db,
        email=f"history-{uuid4().hex}@example.com",
        hashed_password="not-a-real-hash",
    )
    conversation = ConversationService(db).create_conversation(user_id=user.id)
    return user, conversation


@pytest.mark.asyncio
async def test_first_message_names_the_conversation(db_session):
    user, conversation = _user_and_conversation(db_session)
    service = ChatService(db=db_session, provider=ChattyProvider())

    await service.send_message(
        conversation_id=conversation.id,
        user_id=user.id,
        content="Plan my study week for the finals",
    )
    db_session.refresh(conversation)
    assert conversation.title == "Plan my study week for the…"

    # Later messages don't rename it.
    await service.send_message(
        conversation_id=conversation.id,
        user_id=user.id,
        content="Something completely different",
    )
    db_session.refresh(conversation)
    assert conversation.title == "Plan my study week for the…"


@pytest.mark.asyncio
async def test_a_title_the_user_chose_is_kept(db_session):
    user, conversation = _user_and_conversation(db_session)
    ConversationService(db_session).update_title(
        conversation_id=conversation.id,
        user_id=user.id,
        title="My trip",
    )

    await ChatService(db=db_session, provider=ChattyProvider()).send_message(
        conversation_id=conversation.id,
        user_id=user.id,
        content="Find me a hotel",
    )

    db_session.refresh(conversation)
    assert conversation.title == "My trip"


def test_messages_can_be_paged_from_newest(client, db_session):
    email = f"paging-{uuid4().hex}@example.com"
    register_user(client, email=email, password="strong-password-123", full_name="P")
    headers = auth_header(
        login_user(client, email=email, password="strong-password-123").json()[
            "access_token"
        ]
    )
    conversation_id = client.post("/api/v1/conversations", headers=headers).json()["id"]

    for number in range(5):
        response = client.post(
            f"/api/v1/conversations/{conversation_id}/messages",
            headers=headers,
            json={"role": "user", "content": f"message {number}"},
        )
        assert response.status_code == 201

    url = f"/api/v1/conversations/{conversation_id}/messages"

    everything = client.get(url, headers=headers).json()
    assert [m["content"] for m in everything] == [f"message {n}" for n in range(5)]

    newest = client.get(f"{url}?limit=2", headers=headers).json()
    assert [m["content"] for m in newest] == ["message 3", "message 4"]

    older = client.get(f"{url}?limit=2&before={newest[0]['id']}", headers=headers).json()
    assert [m["content"] for m in older] == ["message 1", "message 2"]

    oldest = client.get(f"{url}?limit=2&before={older[0]['id']}", headers=headers).json()
    assert [m["content"] for m in oldest] == ["message 0"]

    assert client.get(f"{url}?limit=0", headers=headers).status_code == 422
    assert client.get(f"{url}?before={uuid4()}", headers=headers).status_code == 404
