from pydantic import BaseModel, Field
from datetime import date
from typing import Optional
from app.models.enums import GraviteEnum


# ─────────────────────────────────────────────
#  Nested schemas
# ─────────────────────────────────────────────

class MachineNestedResponse(BaseModel):
    """Infos minimales de la machine dans l'historique"""
    id_machine: int
    nom: str
    localisation: str

    class Config:
        from_attributes = True


class TypePanneNestedResponse(BaseModel):
    """Infos minimales du type de panne dans l'historique"""
    id_type_panne: int
    nom_panne: str
    gravite: GraviteEnum

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────
#  CREATE
# ─────────────────────────────────────────────

class HistoriquePanneCreate(BaseModel):
    """
    Créer manuellement une entrée d'historique.
    En général, l'historique est créé automatiquement lors de la résolution d'une panne.
    """
    id_panne: int = Field(..., gt=0, description="ID de la panne résolue")
    frequence_panne: Optional[float] = Field(
        default=None,
        ge=0,
        description="Fréquence de récurrence calculée (pannes / mois)"
    )
    dernie_panne: Optional[date] = Field(
        default=None,
        description="Date de la dernière occurrence (défaut : aujourd'hui)"
    )


# ─────────────────────────────────────────────
#  UPDATE
# ─────────────────────────────────────────────

class HistoriquePanneUpdate(BaseModel):
    """Mettre à jour la fréquence ou la date de dernière panne"""
    frequence_panne: Optional[float] = Field(
        default=None,
        ge=0,
        description="Nouvelle fréquence de récurrence"
    )
    dernie_panne: Optional[date] = Field(
        default=None,
        description="Nouvelle date de dernière panne"
    )


# ─────────────────────────────────────────────
#  RESPONSES
# ─────────────────────────────────────────────

class HistoriquePanneResponse(BaseModel):
    """Réponse standard d'un historique de panne"""
    id_panne: int
    id_type_panne: int
    id_machine: int
    frequence_panne: Optional[float] = None
    dernie_panne: Optional[date] = None

    class Config:
        from_attributes = True


class HistoriquePanneDetailResponse(HistoriquePanneResponse):
    """Réponse détaillée avec les relations machine et type_panne"""
    machine: Optional[MachineNestedResponse] = None
    type_panne: Optional[TypePanneNestedResponse] = None

    class Config:
        from_attributes = True