from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.ai.context.builder import ContextBuilder
from app.models.enums import MessageRole
from app.models.message import Message
from app.providers import get_default_provider
from app.providers.base import LLMProvider
from app.repositories.user_repository import UserRepository
from app.services.ai.router.schemas import RouterResponse
from app.services.ai.router.semantic_router import SemanticRouter
from app.services.ai.tools.executor import ToolExecutor
from app.services.ai_service import AIService
from app.services.conversation_service import ConversationService
from app.services.message_service import MessageService


class ChatService:
    def __init__(
        self,
        db: Session,
        provider: LLMProvider | None = None,
        context_builder: ContextBuilder | None = None,
        tool_executor: ToolExecutor | None = None,
    ):
        self.db = db
        self.message_service = MessageService(db)
        self.context_builder = context_builder or ContextBuilder(
            db,
            self.message_service,
        )
        provider = provider or get_default_provider()
        self.router = SemanticRouter(provider)
        self.ai_service = AIService(provider=provider)
        # None: build one per request for the user who is chatting.
        self.tool_executor = tool_executor

    async def send_message(
        self,
        *,
        conversation_id: UUID,
        user_id: UUID,
        content: str,
    ) -> tuple[Message, Message] | None:

        # Generate the response before persisting either message so provider
        # failures cannot leave an orphaned user message.
        history = self.message_service.get_recent_messages(
            conversation_id=conversation_id,
            user_id=user_id,
            limit=20,
        )

        if history is None:
            return None

        tz = self._user_timezone(user_id)

        context = self.context_builder.build(
            user_id=user_id,
            conversation_id=conversation_id,
            recent_messages=history,
        )

        route = await self.router.route(
            content,
            context=context,
            tz=tz,
        )

        extra_data: dict[str, Any] | None = None

        if route.route == "clarification":
            assistant_content = route.message or "Could you give me a bit more detail?"
        elif route.route == "tool":
            executor = self.tool_executor or ToolExecutor.for_user(
                self.db,
                user_id,
                tz,
            )
            assistant_content, extra_data = await self._run_tool(route, executor)
        elif route.message and route.message.strip():
            # The router already answered in the same call; skip a second
            # round trip to the model.
            assistant_content = route.message.strip()
        else:
            assistant_content = await self.ai_service.generate_response(
                history=history,
                pending_user_message=content,
                tz=tz,
            )

        user_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.USER,
            content=content,
        )

        if user_message is None:
            return None

        assistant_message = self.message_service.create_message(
            conversation_id=conversation_id,
            user_id=user_id,
            role=MessageRole.ASSISTANT,
            content=assistant_content,
            extra_data=extra_data,
        )

        if assistant_message is None:
            return None

        # First exchange: give the conversation a real title.
        if not history and self.db is not None:
            ConversationService(self.db).set_title_from_first_message(
                conversation_id=conversation_id,
                user_id=user_id,
                content=content,
            )

        return user_message, assistant_message

    def _user_timezone(self, user_id: UUID) -> str | None:
        """The user's IANA time zone (set by the app from the device), or
        None to fall back to the server's local time."""
        if self.db is None:
            return None
        user = UserRepository.get_by_id(self.db, user_id)
        return user.timezone if user is not None else None

    async def _run_tool(
        self,
        route: RouterResponse,
        executor: ToolExecutor,
    ) -> tuple[str, dict[str, Any]]:
        extra_data: dict[str, Any] = {
            "route": "tool",
            "tool": route.tool,
            "arguments": route.arguments,
        }

        try:
            result = await executor.execute(route)
        except (TypeError, ValueError):
            # Missing or unexpected arguments from the model.
            extra_data["error"] = "invalid_arguments"
            return (
                "I couldn't do that yet. Could you give me a few more details?",
                extra_data,
            )

        extra_data["result"] = result
        return self._describe_tool_result(route.tool, result), extra_data

    @staticmethod
    def _describe_tool_result(tool: str | None, result: Any) -> str:
        result = result or {}

        if tool == "create_task":
            text = f"Task created: {result.get('title')}"
            if result.get("due_date"):
                text += f" (due {result['due_date']})"
            return text + "."

        if tool == "create_reminder":
            when = result.get("date") or ""
            if result.get("time"):
                when = f"{when} at {result['time']}"
            return f"Reminder set: {result.get('title')} on {when}."

        if tool == "get_tasks":
            tasks = result.get("tasks") or []
            if not tasks:
                return "You don't have any tasks yet."
            lines = "\n".join(
                f"- {task.get('title')}"
                + (f" (due {task['due_date']})" if task.get("due_date") else "")
                for task in tasks
            )
            return f"Here are your open tasks:\n{lines}"

        if tool == "list_reminders":
            reminders = result.get("reminders") or []
            if not reminders:
                return "You don't have any upcoming reminders."
            lines = "\n".join(
                f"- {item.get('title')} on {item.get('date')}"
                + (f" at {item['time']}" if item.get("time") else "")
                for item in reminders
            )
            return f"Here are your upcoming reminders:\n{lines}"

        return "Done."
