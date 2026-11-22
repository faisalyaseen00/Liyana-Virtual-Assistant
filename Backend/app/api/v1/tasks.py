from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session

from app.dependencies.auth import CurrentUser
from app.dependencies.db import get_db
from app.schemas.task import TaskCreate, TaskResponse, TaskUpdate
from app.services.task_service import TaskService

router = APIRouter(
    prefix="/tasks",
    tags=["Tasks"],
)


def _not_found() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail="Task not found.",
    )


@router.get("", response_model=list[TaskResponse])
def list_tasks(
    current_user: CurrentUser,
    completed: bool | None = None,
    db: Session = Depends(get_db),
):
    return TaskService(db, current_user.id).list_tasks(completed=completed)


@router.post(
    "",
    response_model=TaskResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_task(
    data: TaskCreate,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    return TaskService(db, current_user.id).create(data)


@router.get("/{task_id}", response_model=TaskResponse)
def get_task(
    task_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    task = TaskService(db, current_user.id).get(task_id)
    if task is None:
        raise _not_found()
    return task


@router.patch("/{task_id}", response_model=TaskResponse)
def update_task(
    task_id: UUID,
    data: TaskUpdate,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    task = TaskService(db, current_user.id).update(task_id, data)
    if task is None:
        raise _not_found()
    return task


@router.delete("/{task_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_task(
    task_id: UUID,
    current_user: CurrentUser,
    db: Session = Depends(get_db),
):
    if not TaskService(db, current_user.id).delete(task_id):
        raise _not_found()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
