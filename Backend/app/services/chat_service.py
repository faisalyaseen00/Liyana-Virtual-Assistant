from uuid import UUID

from sqlalchemy.orm import Session

from app.models.enums import MessageRole
from app.models.message import Message
from app.providers.grok import GrokProvider
from app.services.ai_service import AIService
from app.services.message_service import MessageService


class ChatService:
    def __init__(self, db: Session):
        self.message_service = MessageService(db)
        self.ai_service = AIService(
            provider=GrokProvider(),
        )

    async def send_message(
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

        # 2. Get recent conversation history
        history = self.message_service.get_recent_messages(
            conversation_id=conversation_id,
            user_id=user_id,
            limit=20,
        )

        if history is None:
            return None

        # 3. Generate AI response using conversation history
        assistant_content = await self.ai_service.generate_response(
            history=history,
        )

        # 4. Save assistant message
        assistant_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.ASSISTANT,
            content=assistant_content,
        )

        if assistant_message is None:
            return None

        return user_message, assistant_message