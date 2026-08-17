from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass
class LLMMessage:
    role: str
    content: str


class LLMProvider(ABC):

    @abstractmethod
    async def generate(
        self,
        messages: list[LLMMessage],
    ) -> str:
        pass
    