from datetime import date, datetime, time
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ReminderCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    title: str = Field(min_length=1, max_length=255)
    remind_date: date
    remind_time: time | None = None


class ReminderUpdate(BaseModel):
    """Partial update: only the fields that are sent are changed."""

    model_config = ConfigDict(str_strip_whitespace=True)

    title: str | None = Field(default=None, min_length=1, max_length=255)
    remind_date: date | None = None
    remind_time: time | None = None
    is_done: bool | None = None


class ReminderResponse(BaseModel):
    id: UUID
    title: str
    remind_date: date
    remind_time: time | None
    is_done: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
