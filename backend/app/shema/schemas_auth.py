# schemas/auth.py

from pydantic import BaseModel
from typing import Optional


class LoginRequest(BaseModel):
    email: str  # email ou nom d'utilisateur
    mot_de_passe: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    user_id: int
    nom: str
    prenom: str


class TokenData(BaseModel):
    user_id: Optional[int] = None
    role: Optional[str] = None
