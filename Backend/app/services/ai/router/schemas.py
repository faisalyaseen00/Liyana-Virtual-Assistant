from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class RouterResponse(BaseModel):
    route: Literal["tool", "conversation", "clarification"]
    tool: str | None = None
    arguments: dict[str, Any] = Field(default_factory=dict)
    message: str | None = None

    @field_validator("arguments", mode="before")
    @classmethod
    def _none_to_empty(cls, value: Any) -> Any:
        # Models often send "arguments": null for tools without parameters.
        return {} if value is None else value