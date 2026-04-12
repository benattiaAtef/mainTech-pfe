
from dataclasses import Field
from typing import Optional

from pydantic import BaseModel, EmailStr

from app.shema.user import UtilisateurResponse




class ChefEquipeCreate(BaseModel):
    nom: str
    prenom: str
    email: EmailStr
    mot_de_passe: str
    id_groupe_supervise: Optional[int] = None


class ChefEquipeUpdate(BaseModel):
    id_groupe_supervise: int 


class ChefEquipeResponse(BaseModel):
    id_chef: int
    id_utilisateur: int
    id_groupe_supervise: int | None
    utilisateur: UtilisateurResponse 

    model_config = {"from_attributes": True}