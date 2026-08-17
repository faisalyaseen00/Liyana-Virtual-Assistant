from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, ConfigDict

from app.models.enums import MessageRole


class MessageCreate(BaseModel):
    role: MessageRole
    content: str
    extra_data: dict | None = None


class MessageUpdate(BaseModel):
    content: str


class MessageResponse(BaseModel):
    id: UUID
    conversation_id: UUID
    role: MessageRole
    content: str
    extra_data: dict | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)