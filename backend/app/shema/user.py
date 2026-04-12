




from typing import Optional
from pydantic import BaseModel, EmailStr, Field

from app.models.enums import RoleEnum, StatutPresenceEnum


class UtilisateurBase(BaseModel):
    """Schéma de base pour un utilisateur"""
    nom: str = Field(..., min_length=1, max_length=100)
    prenom: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    role: RoleEnum
    statut_presence: StatutPresenceEnum = StatutPresenceEnum.EN_TRAVAIL


class UtilisateurCreate(UtilisateurBase):
    """Schéma pour créer un utilisateur"""
    mot_de_passe: str = Field(..., min_length=8, max_length=72)


class UtilisateurUpdate(BaseModel):
    """Schéma pour mettre à jour un utilisateur"""
    nom: Optional[str] = Field(None, min_length=1, max_length=100)
    prenom: Optional[str] = Field(None, min_length=1, max_length=100)
    email: Optional[EmailStr] = None
    mot_de_passe: Optional[str] = Field(None, min_length=8)
    role: Optional[RoleEnum] = None
    statut_presence: Optional[StatutPresenceEnum] = None


class UtilisateurInDB(UtilisateurBase):
    """Schéma pour un utilisateur en base de données"""
    id_utilisateur: int
    


class UtilisateurResponse(UtilisateurInDB):
    """Schéma de réponse API (sans mot de passe)"""
    fcm_token: Optional[str] = None
    class Config:
        from_attributes = True

class FCMTokenUpdate(BaseModel):
    fcm_token: str