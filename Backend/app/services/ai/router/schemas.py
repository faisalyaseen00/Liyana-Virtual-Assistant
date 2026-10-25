from typing import Any, Literal
from pydantic import BaseModel, Field

class RouterResponse(BaseModel):
    route: Literal["tool", "conversation", "clarification"]
    tool: str | None = None
    arguments: dict[str, Any] = Field(default_factory=dict)
    message: str | None = None