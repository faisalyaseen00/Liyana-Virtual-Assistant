from pydantic import BaseModel, Field


class ToolDefinition(BaseModel):
    name: str = Field(min_length=1)
    description: str = Field(min_length=1)
    parameters: dict = Field(default_factory=dict)


CREATE_TASK = ToolDefinition(
    name="create_task",
    description=(
        "Create a new task (to-do item) for the user. Use this when the user "
        "asks to add, make or create a task, assignment, deadline or to-do. "
        "Reminders are set automatically from the deadline, so do not also "
        "call create_reminder. Only fill remind_date/remind_time when the "
        "user says when they want to be reminded."
    ),
    parameters={
        "title": {
            "type": "string",
            "description": "Short task name, without the date words",
            "required": True,
        },
        "due_date": {
            "type": "string",
            "format": "YYYY-MM-DD",
            "description": "Deadline date; work out weekdays and "
            "'next week' from today's date",
            "required": False,
        },
        "due_time": {
            "type": "string",
            "format": "HH:MM (24-hour)",
            "description": "Deadline time, if the user gave one",
            "required": False,
        },
        "remind_date": {
            "type": "string",
            "format": "YYYY-MM-DD",
            "required": False,
        },
        "remind_time": {
            "type": "string",
            "format": "HH:MM (24-hour)",
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