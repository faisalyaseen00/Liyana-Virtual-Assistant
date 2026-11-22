from pydantic import BaseModel, Field


class ToolDefinition(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    parameters: dict = Field(default_factory=dict)


CREATE_TASK = ToolDefinition(
    name="create_task",
    description="Create a new task (to-do item) for the user.",
    parameters={
        "title": {
            "type": "string",
            "required": True,
        },
        "due_date": {
            "type": "string",
            "format": "YYYY-MM-DD",
            "required": False,
        },
        "priority": {
            "type": "string",
            "enum": ["low", "medium", "high"],
            "required": False,
        },
        "description": {
            "type": "string",
            "required": False,
        },
    },
)

GET_TASKS = ToolDefinition(
    name="get_tasks",
    description="List the user's open (not completed) tasks.",
    parameters={},
)

LIST_REMINDERS = ToolDefinition(
    name="list_reminders",
    description="List the user's upcoming (not done) reminders.",
    parameters={},
)

CREATE_REMINDER = ToolDefinition(
    name="create_reminder",
    description="Create a reminder for the user at a date and optional time.",
    parameters={
        "title": {
            "type": "string",
            "required": True,
        },
        "date": {
            "type": "string",
            "format": "YYYY-MM-DD",
            "required": True,
        },
        "time": {
            "type": "string",
            "format": "HH:MM (24-hour)",
            "required": False,
        },
    },
)