from uuid import UUID

from sqlalchemy.orm import Session

from app.models.enums import MessageRole
from app.models.message import Message
from app.services.message_service import MessageService


class ChatService:
    def __init__(self, db: Session):
        self.message_service = MessageService(db)

    def send_message(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        content: str,
    ) -> tuple[Message, Message] | None:

        # 1. Save user message
        user_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.USER,
            content=content,
        )

        if user_message is None:
            return None

        # 2. Temporary assistant response
        assistant_content = (
            "I received your message. "
            "The Liyana AI engine will process this message here."
        )

        # 3. Save assistant message
        assistant_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.ASSISTANT,
            content=assistant_content,
        )

        if assistant_message is None:
            return None

        return user_message, assistant_message