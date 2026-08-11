from uuid import UUID

from sqlalchemy.orm import Session

from app.models.enums import MessageRole
from app.models.message import Message
from app.repositories.conversation_repository import ConversationRepository
from app.repositories.message_repository import MessageRepository


class MessageService:
    def __init__(self, db: Session):
        self.message_repository = MessageRepository(db)
        self.conversation_repository = ConversationRepository(db)

    def create_message(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        role: MessageRole,
        content: str,
        extra_data: dict | None = None,
    ) -> Message | None:

        conversation = self.conversation_repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return None

        message = self.message_repository.create(
            conversation_id=conversation_id,
            role=role,
            content=content,
            extra_data=extra_data,
        )

        self.conversation_repository.update_last_message_at(
            conversation,
        )

        return message

    def get_message(
        self,
        *,
        message_id: UUID,
        user_id: UUID,
    ) -> Message | None:

        message = self.message_repository.get_by_id(
            message_id,
        )

        if message is None:
            return None

        conversation = self.conversation_repository.get_by_id_for_user(
            conversation_id=message.conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return None

        return message

    def get_conversation_messages(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
    ) -> list[Message] | None:

        conversation = self.conversation_repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return None

        return self.message_repository.get_by_conversation(
            conversation_id,
        )

    def get_recent_messages(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        limit: int = 20,
    ) -> list[Message] | None:

        conversation = self.conversation_repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return None

        return self.message_repository.get_recent_by_conversation(
            conversation_id=conversation_id,
            limit=limit,
        )