from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from app.shema.user import UtilisateurResponse

class MagasinierBase(BaseModel):
    pass

class MagasinierCreate(BaseModel):
    nom: str
    prenom: str
    email: EmailStr
    mot_de_passe: str = Field(..., min_length=6)

class MagasinierUpdate(BaseModel):
    nom: Optional[str] = None
    prenom: Optional[str] = None
    email: Optional[EmailStr] = None
    mot_de_passe: Optional[str] = None

class MagasinierResponse(BaseModel):
    id_magasinier: int
    id_utilisateur: int
    utilisateur: UtilisateurResponse

    class Config:
        from_attributes = True
