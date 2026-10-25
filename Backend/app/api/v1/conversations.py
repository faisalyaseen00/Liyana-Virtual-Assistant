from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser
from app.dependencies.db import get_db
from app.schemas.conversation import ConversationResponse
from app.services.conversation_service import ConversationService

from app.schemas.conversation import (
    ConversationResponse,
    ConversationUpdate,
)
router = APIRouter(
    prefix="/conversations",
    tags=["Conversations"],
)


@router.post(
    "",
    response_model=ConversationResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_conversation(
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> ConversationResponse:
    service = ConversationService(db)

    conversation = service.create_conversation(
        user_id=current_user.id,
    )

    return conversation


@router.get(
    "",
    response_model=list[ConversationResponse],
)
def get_conversations(
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> list[ConversationResponse]:
    service = ConversationService(db)

    return service.get_user_conversations(
        user_id=current_user.id,
    )


@router.get(
    "/{conversation_id}",
    response_model=ConversationResponse,
)
def get_conversation(
    conversation_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> ConversationResponse:
    service = ConversationService(db)

    conversation = service.get_conversation(
        conversation_id=conversation_id,
        user_id=current_user.id,
    )

    if conversation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    return conversation

@router.patch(
    "/{conversation_id}",
    response_model=ConversationResponse,
)
def update_conversation(
    conversation_id: UUID,
    data: ConversationUpdate,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
) -> ConversationResponse:

    service = ConversationService(db)

    conversation = service.update_title(
        conversation_id=conversation_id,
        user_id=current_user.id,
        title=data.title,
    )

    if conversation is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )

    return conversation

@router.delete(
    "/{conversation_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_conversation(
    conversation_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
    ) -> None:

    service = ConversationService(db)

    deleted = service.delete_conversation(
        conversation_id=conversation_id,
        user_id=current_user.id,
    )

    if not deleted:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Conversation not found.",
        )