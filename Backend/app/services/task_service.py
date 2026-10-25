from typing import Any


class TaskService:
    """Thin task service layer for the Liyana tool executor.

    This keeps the AI tool executor focused on dispatch only; the concrete
    task logic remains in this service class and can later be backed by a DB or
    repository layer without changing the tool interface.
    """

    async def create_task(
        self,
        *,
        title: str,
        due_date: str | None = None,
        **_: Any,
    ) -> dict[str, Any]:
        return {
            "title": title,
            "due_date": due_date,
        }

    async def get_tasks(self, **_: Any) -> dict[str, list[dict[str, Any]]]:
        return {"tasks": []}
