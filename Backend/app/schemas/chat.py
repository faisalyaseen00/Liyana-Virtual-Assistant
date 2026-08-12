from pydantic import BaseModel

from app.schemas.message import MessageResponse


class ChatRequest(BaseModel):
    content: str


class ChatResponse(BaseModel):
    user_message: MessageResponse
    assistant_message: MessageResponse