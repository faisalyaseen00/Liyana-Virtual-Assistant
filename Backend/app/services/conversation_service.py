from uuid import UUID

from sqlalchemy.orm import Session

from app.models.conversation import Conversation
from app.repositories.conversation_repository import ConversationRepository


class ConversationService:
    def __init__(self, db: Session):
        self.repository = ConversationRepository(db)

    def create_conversation(
        self,
        *,
        user_id: UUID,
        title: str = "New Conversation",
    ) -> Conversation:

        return self.repository.create(
            user_id=user_id,
            title=title,
        )

    def get_conversation(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
    ) -> Conversation | None:

        return self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

    def get_user_conversations(
        self,
        *,
        user_id: UUID,
    ) -> list[Conversation]:

        return self.repository.get_by_user(user_id)

    def update_title(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        title: str,
    ) -> Conversation | None:

        conversation = self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return None

        self.repository.update_title(
            conversation,
            title,
        )

        return conversation

    def delete_conversation(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
    ) -> bool:

        conversation = self.repository.get_by_id_for_user(
            conversation_id=conversation_id,
            user_id=user_id,
        )

        if conversation is None:
            return False

        self.repository.delete(conversation)

        return True