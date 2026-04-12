from dataclasses import Field
from typing import Optional
from typing import Optional

from pydantic import BaseModel

from app.models.users import Utilisateur
from app.shema.user import UtilisateurResponse


class SuperviseurCreate(BaseModel):
    nom: str
    prenom: str
    email: str
    mot_de_passe: str
    zone_responsabilite: str

class SuperviseurUpdate(BaseModel):
    zone_responsabilite: str 


class SuperviseurResponse(BaseModel):
    id_superviseur: int
    id_utilisateur: int
    zone_responsabilite: str | None
    utilisateur: UtilisateurResponse

    model_config = {"from_attributes": True}