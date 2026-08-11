from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser
from app.dependencies.db import get_db
from app.schemas.message import MessageCreate, MessageResponse
from app.services.message_service import MessageService


router = APIRouter(
    prefix="/conversations/{conversation_id}/messages",
    tags=["Messages"],
)


@router.post(
    "",
    response_model=MessageResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_message(
    conversation_id: UUID,
    data: MessageCreate,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> MessageResponse:

    service = MessageService(db)

    message = service.create_message(
        conversation_id=conversation_id,
        user_id=current_user.id,
        role=data.role,
        content=data.content,
        extra_data=data.extra_data,
    )

    if message is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    return message


@router.get(
    "",
    response_model=list[MessageResponse],
)
def get_messages(
    conversation_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> list[MessageResponse]:

    service = MessageService(db)

    messages = service.get_conversation_messages(
        conversation_id=conversation_id,
        user_id=current_user.id,
    )

    if messages is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    return messages