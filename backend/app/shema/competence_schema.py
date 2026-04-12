from pydantic import BaseModel
from typing import Optional

class GroupeTechnicienCreate(BaseModel):
    nom_groupe: str
    nombre_min_dispo: Optional[int] = 1

class GroupeMachineCreate(BaseModel):
    nom_groupe: str
    niveau_priorite: Optional[int] = 1
    id_groupe_tech_principal: Optional[int] = None
