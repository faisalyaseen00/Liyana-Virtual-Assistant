from typing import Any
from uuid import UUID

from app.models.message import Message
from app.repositories.user_repository import UserRepository
from app.services.message_service import MessageService


class ContextBuilder:
    MAX_MESSAGES = 10
    MAX_MESSAGE_LENGTH = 800

    def __init__(
        self,
        db: Any,
        message_service: MessageService,
        user_repository: Any = UserRepository,
    ):
        self.db = db
        self.message_service = message_service
        self.user_repository = user_repository

    def build(
        self,
        *,
        user_id: UUID,
        conversation_id: UUID,
        recent_messages: list[Message] | None = None,
    ) -> str:
        user = None
        if self.db is not None:
            user = self.user_repository.get_by_id(self.db, user_id)

        if recent_messages is None:
            recent_messages = self.message_service.get_recent_messages(
                conversation_id=conversation_id,
                user_id=user_id,
                limit=self.MAX_MESSAGES,
            ) or []

        parts: list[str] = []
        if user is not None:
            parts.append(
                "User: "
                f"name={user.full_name or 'unknown'}; "
                f"timezone={user.timezone}; language={user.language}"
            )

        if recent_messages:
            parts.append("Recent conversation:")
            parts.extend(
                f"- {message.role.value}: {self._compact(message.content)}"
                for message in recent_messages[-self.MAX_MESSAGES:]
            )

        return "\n".join(parts)

    @classmethod
    def _compact(cls, content: str) -> str:
        content = " ".join(content.split())
        if len(content) <= cls.MAX_MESSAGE_LENGTH:
            return content
        return f"{content[: cls.MAX_MESSAGE_LENGTH - 3]}..."
