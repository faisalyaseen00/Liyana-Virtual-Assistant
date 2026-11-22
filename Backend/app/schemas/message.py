from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

from app.models.enums import MessageRole


class MessageCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    role: MessageRole
    content: str = Field(min_length=1, max_length=4000)
    extra_data: dict | None = None


class MessageUpdate(BaseModel):
    content: str = Field(min_length=1, max_length=4000)


class MessageResponse(BaseModel):
    id: UUID
    conversation_id: UUID
    role: MessageRole
    content: str
    extra_data: dict | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)