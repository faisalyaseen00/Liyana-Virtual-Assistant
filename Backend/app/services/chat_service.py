from uuid import UUID

from sqlalchemy.orm import Session

from app.ai.context.builder import ContextBuilder
from app.models.enums import MessageRole
from app.models.message import Message
from app.providers.base import LLMProvider
from app.providers.grok import GrokProvider
from app.services.ai.router.semantic_router import SemanticRouter
from app.services.ai_service import AIService
from app.services.message_service import MessageService


class ChatService:
    def __init__(
        self,
        db: Session,
        provider: LLMProvider | None = None,
        context_builder: ContextBuilder | None = None,
    ):
        self.message_service = MessageService(db)
        self.context_builder = context_builder or ContextBuilder(
            db,
            self.message_service,
        )
        provider = provider or GrokProvider()
        self.router = SemanticRouter(provider)
        self.ai_service = AIService(provider=provider)

    async def send_message(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        content: str,
    ) -> tuple[Message, Message] | None:

        # Generate the response before persisting either message so provider
        # failures cannot leave an orphaned user message.
        history = self.message_service.get_recent_messages(
            conversation_id=conversation_id,
            user_id=user_id,
            limit=20,
        )

        if history is None:
            return None

        context = self.context_builder.build(
            user_id=user_id,
            conversation_id=conversation_id,
            recent_messages=history,
        )

        route = await self.router.route(
            content,
            context=context,
        )

        if route.route == "clarification":
            assistant_content = route.message or ""
        elif route.route == "conversation":
            assistant_content = await self.ai_service.generate_response(
                history=history,
                pending_user_message=content,
            )
        else:
            raise ValueError(f"Unsupported chat route: {route.route}")

        user_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.USER,
            content=content,
        )

        if user_message is None:
            return None

        assistant_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.ASSISTANT,
            content=assistant_content,
        )

        if assistant_message is None:
            return None

        return user_message, assistant_message