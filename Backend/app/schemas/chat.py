from pydantic import BaseModel, ConfigDict, Field

from app.schemas.message import MessageResponse


class ChatRequest(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True)

    content: str = Field(min_length=1, max_length=4000)


class ChatResponse(BaseModel):
    user_message: MessageResponse
    assistant_message: MessageResponse