from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser
from app.dependencies.db import get_db
from app.schemas.reminder import ReminderCreate, ReminderResponse, ReminderUpdate
from app.services.reminder_service import ReminderService

router = APIRouter(
    prefix="/reminders",
    tags=["Reminders"],
)


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Reminder not found.",
    )


@router.get("", response_model=list[ReminderResponse])
def list_reminders(
    current_user: CurrentUser,
    done: bool | None = None,
    db: Session = Depends(get_db),
):
    return ReminderService(db, current_user.id).list_reminders(done=done)


@router.post(
    "",
    response_model=ReminderResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_reminder(
    data: ReminderCreate,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    return ReminderService(db, current_user.id).create(data)


@router.get("/{reminder_id}", response_model=ReminderResponse)
def get_reminder(
    reminder_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    reminder = ReminderService(db, current_user.id).get(reminder_id)
    if reminder is None:
        raise _not_found()
    return reminder


@router.patch("/{reminder_id}", response_model=ReminderResponse)
def update_reminder(
    reminder_id: UUID,
    data: ReminderUpdate,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    reminder = ReminderService(db, current_user.id).update(reminder_id, data)
    if reminder is None:
        raise _not_found()
    return reminder


@router.delete("/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reminder(
    reminder_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    if not ReminderService(db, current_user.id).delete(reminder_id):
        raise _not_found()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
