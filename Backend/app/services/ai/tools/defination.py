from pydantic import BaseModel, Field


class ToolDefinition(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    parameters: dict = Field(default_factory=dict)


CREATE_TASK = ToolDefinition(
    name="create_task",
    description="Create a new task for the user.",
    parameters={
        "title": {
            "type": "string",
            "required": True,
        },
        "due_date": {
            "type": "string",
            "required": False,
        },
    },
)

GET_TASKS = ToolDefinition(
    name="get_tasks",
    description="Get the user's tasks.",
    parameters={},
)

CREATE_REMINDER = ToolDefinition(
    name="create_reminder",
    description="Create a reminder for the user.",
    parameters={
        "title": {
            "type": "string",
            "required": True,
        },
        "date": {
            "type": "string",
            "required": True,
        },
        "time": {
            "type": "string",
            "required": False,
        },
    },
)