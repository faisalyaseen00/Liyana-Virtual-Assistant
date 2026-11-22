import logging
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser
from app.dependencies.db import get_db
from app.schemas.chat import ChatRequest, ChatResponse
from app.services.chat_service import ChatService

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/conversations/{conversation_id}/chat",
    tags=["Chat"],
)


@router.post(
    "",
    response_model=ChatResponse,
    status_code=status.HTTP_201_CREATED,
)
async def send_message(
    conversation_id: UUID,
    data: ChatRequest,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> ChatResponse:

    service = ChatService(db)

    try:
        result = await service.send_message(
            conversation_id=conversation_id,
            user_id=current_user.id,
            content=data.content,
        )
    except Exception as exc:
        # Keep the real error in the server log; the client gets a 502.
        logger.exception("Chat request failed")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="AI provider is unavailable.",
        ) from exc

    if result is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    user_message, assistant_message = result

    return ChatResponse(
        user_message=user_message,
        assistant_message=assistant_message,
    )