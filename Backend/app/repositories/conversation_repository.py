from datetime import datetime, timezone
UTC = timezone.utc
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.conversation import DEFAULT_TITLE, Conversation


class ConversationRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        *,
        user_id: UUID,
        title: str = DEFAULT_TITLE,
    ) -> Conversation:

        conversation = Conversation(
            user_id=user_id,
            title=title,
        )

        self.db.add(conversation)
        self.db.commit()
        self.db.refresh(conversation)

        return conversation

    def get_by_id(
        self,
        conversation_id: UUID,
    ) -> Conversation | None:

        statement = select(Conversation).where(
            Conversation.id == conversation_id
        )

        return self.db.scalar(statement)

    def get_by_id_for_user(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
    ) -> Conversation | None:

        statement = select(Conversation).where(
            Conversation.id == conversation_id,
            Conversation.user_id == user_id,
        )

        return self.db.scalar(statement)

    def get_by_user(
        self,
        user_id: UUID,
    ) -> list[Conversation]:

        statement = (
            select(Conversation)
            .where(Conversation.user_id == user_id)
            .order_by(Conversation.last_message_at.desc())
        )

        return list(self.db.scalars(statement).all())

    def update_last_message_at(
        self,
        conversation: Conversation,
    ) -> None:

        conversation.last_message_at = datetime.now(UTC)
        conversation.updated_at = datetime.now(UTC)

        self.db.commit()
        self.db.refresh(conversation)

    def update_title(
        self,
        conversation: Conversation,
        title: str,
    ) -> None:

        conversation.title = title
        conversation.updated_at = datetime.now(UTC)

        self.db.commit()
        self.db.refresh(conversation)

    def delete(
        self,
        conversation: Conversation,
    ) -> None:

        self.db.delete(conversation)
        self.db.commit()