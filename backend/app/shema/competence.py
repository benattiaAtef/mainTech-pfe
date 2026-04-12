from pydantic import BaseModel
from app.models.enums import NiveauExpertiseEnum

class CompetenceTechnicienBase(BaseModel):
    id_technicien: int
    id_groupe_machine: int
    niveau_expertise: NiveauExpertiseEnum


class CompetenceTechnicienCreate(CompetenceTechnicienBase):
    pass