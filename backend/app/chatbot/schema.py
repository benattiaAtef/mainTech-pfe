from pydantic import BaseModel
from typing import Optional


class ChatbotRequest(BaseModel):
    message: str
    machine_context: Optional[str] = None  # Ex: "Machine 3 - Fraiseuse CNC"


class ChatbotResponse(BaseModel):
    reply: str
