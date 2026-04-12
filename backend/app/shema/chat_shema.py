from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ChatMessageBase(BaseModel):
    contenu: str

class ChatMessageCreate(ChatMessageBase):
    pass

class ChatMessageResponse(ChatMessageBase):
    id_message: int
    id_expediteur: int
    id_groupe: int
    date_envoi: datetime
    expediteur_nom: Optional[str] = None
    expediteur_prenom: Optional[str] = None

    class Config:
        from_attributes = True
