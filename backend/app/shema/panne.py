from datetime import datetime
from typing import Optional
from pydantic import BaseModel, Field

from app.models.enums import StatutPanneEnum, GraviteEnum


class PanneCreate(BaseModel):
    id_machine: Optional[int] = Field(None, gt=0)
    qr_code: Optional[str] = None
    id_type_panne: int  = Field(..., gt=0)
    id_superviseur: Optional[int] = Field(None, gt=0)
    priorite: int = Field(default=3, ge=1, le=5, description="1=critique, 5=faible")
    gravite: Optional[GraviteEnum] = None

class PanneUpdateStatut(BaseModel):
    statut: StatutPanneEnum


class PanneResponse(BaseModel):
    id_panne: int
    id_machine: int
    id_type_panne: int
    id_superviseur: int
    priorite: int | None
    statut: StatutPanneEnum
    date_declaration: datetime

    model_config = {"from_attributes": True}


class PanneDeclarationResult(BaseModel):
    panne: PanneResponse
    intervention_id: int | None
    technicien_id: int | None
    type_affectation: str | None
    message: str

    
class PanneDetailResponse(PanneResponse):
    """Réponse enrichie avec infos technicien affecté"""
    technicien_affecte: Optional[dict] = None
    notification_envoyee: bool = False
    message: Optional[str] = None

