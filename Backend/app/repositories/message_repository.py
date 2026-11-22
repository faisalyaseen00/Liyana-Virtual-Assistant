from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.enums import MessageRole
from app.models.message import Message


class MessageRepository:
    def __init__(self, db: Session):
        self.db = db

    def create(
        self,
        *,
        conversation_id: UUID,
        role: MessageRole,
        content: str,
        extra_data: dict | None = None,
    ) -> Message:

        message = Message(
            conversation_id=conversation_id,
            role=role,
            content=content,
            extra_data=extra_data,
        )

        self.db.add(message)
        self.db.commit()
        self.db.refresh(message)

        return message

    def get_by_id(
        self,
        message_id: UUID,
    ) -> Message | None:

        statement = select(Message).where(
            Message.id == message_id
        )

        return self.db.scalar(statement)

    def get_by_conversation(
        self,
        conversation_id: UUID,
        *,
        before: Message | None = None,
        limit: int | None = None,
    ) -> list[Message]:
        """Messages oldest first. With `limit`, returns the newest `limit`
        messages (older than `before`, if given) — for paging back through a
        long chat."""

        statement = select(Message).where(
            Message.conversation_id == conversation_id
        )

        if before is not None:
            statement = statement.where(Message.created_at < before.created_at)

        if limit is None:
            return list(
                self.db.scalars(statement.order_by(Message.created_at.asc())).all()
            )

        newest_first = self.db.scalars(
            statement.order_by(Message.created_at.desc()).limit(limit)
        ).all()
        return list(reversed(newest_first))

    def get_recent_by_conversation(
        self,
        conversation_id: UUID,
        limit: int = 20,
    ) -> list[Message]:

        statement = (
            select(Message)
            .where(
                Message.conversation_id == conversation_id
            )
            .order_by(Message.created_at.desc())
            .limit(limit)
        )

        messages = list(self.db.scalars(statement).all())

        return list(reversed(messages))

    def update(
        self,
        message: Message,
        *,
        content: str,
    ) -> Message:

        message.content = content

        self.db.commit()
        self.db.refresh(message)

        return message

    def delete(
        self,
        message: Message,
    ) -> None:

        self.db.delete(message)
        self.db.commit()