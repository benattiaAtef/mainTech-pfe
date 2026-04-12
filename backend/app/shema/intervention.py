from pydantic import BaseModel, Field, model_validator, ConfigDict
from datetime import datetime
from typing import Optional, List, Dict, Any
from app.models.enums import TypeAffectationEnum, StatutInterventionEnum


# ─────────────────────────────────────────────
#  Nested schemas (pour les relations)
# ─────────────────────────────────────────────

class TechnicienNestedResponse(BaseModel):
    """Infos minimales du technicien imbriqué dans une intervention"""
    id_technicien: int
    id_utilisateur: int
    nom: Optional[str] = None
    prenom: Optional[str] = None
    utilisateur: Optional[Dict[str, Any]] = None

    @model_validator(mode='before')
    @classmethod
    def from_orm_custom(cls, data: Any) -> Any:
        if hasattr(data, 'utilisateur') and data.utilisateur:
            u = data.utilisateur
            return {
                "id_technicien": data.id_technicien,
                "id_utilisateur": data.id_utilisateur,
                "nom": u.nom,
                "prenom": u.prenom,
                "utilisateur": {
                    "nom": u.nom,
                    "prenom": u.prenom,
                    "email": u.email,
                    "id_utilisateur": u.id_utilisateur
                }
            }
        return data

    model_config = ConfigDict(from_attributes=True)


from app.shema.machine import MachineResponse


class PanneNestedResponse(BaseModel):
    """Infos minimales de la panne imbriquée dans une intervention"""
    id_panne: int
    id_machine: int
    priorite: int
    statut: str
    machine: Optional[MachineResponse] = None

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────
#  CREATE
# ─────────────────────────────────────────────

class InterventionCreate(BaseModel):
    """Créer manuellement une intervention (affectation manuelle)"""
    id_panne: int = Field(..., gt=0, description="ID de la panne à traiter")
    id_technicien: int = Field(..., gt=0, description="ID du technicien affecté")
    type_affectation: TypeAffectationEnum = Field(
        default=TypeAffectationEnum.MANUELLE,
        description="Type d'affectation"
    )
    date_debut: Optional[datetime] = Field(
        default=None,
        description="Date/heure de début (défaut : maintenant)"
    )

    class Config:
        use_enum_values = True


# ─────────────────────────────────────────────
#  UPDATE
# ─────────────────────────────────────────────

class InterventionUpdate(BaseModel):
    """Mettre à jour une intervention (ex: corriger le type d'affectation)"""
    type_affectation: Optional[TypeAffectationEnum] = None
    date_fin: Optional[datetime] = None

    class Config:
        use_enum_values = True


# ─────────────────────────────────────────────
#  RAPPORT (Bon de Travail)
# ─────────────────────────────────────────────

class RapportPanneCreate(BaseModel):
    description_panne: Optional[str] = None
    travaux_effectues: Optional[str] = None
    type_travail: Optional[str] = None # MCP, MNP, AUT
    codes_defaut: Optional[Dict[str, Any]] = None # {what, why, where}
    pieces_rechange: Optional[List[Dict[str, Any]]] = None # [{part_name, quantity}]
    temps_arret: Optional[int] = None
    observations: Optional[str] = None
    # Nouveaux champs
    causes: Optional[str] = None
    solutions: Optional[str] = None
    etat_final: Optional[str] = None

class RapportPanneResponse(RapportPanneCreate):
    id_rapport: int
    id_intervention: int
    date_rapport: datetime

    class Config:
        from_attributes = True


# ─────────────────────────────────────────────
#  RESPONSES
# ─────────────────────────────────────────────

class InterventionResponse(BaseModel):
    """Réponse standard d'une intervention"""
    id_intervention: int
    id_panne: int
    id_technicien: int
    date_debut: datetime
    date_acceptation: Optional[datetime] = None
    date_scan_qr: Optional[datetime] = None
    date_fin: Optional[datetime] = None
    type_affectation: Optional[TypeAffectationEnum] = TypeAffectationEnum.AUTOMATIQUE
    statut: Optional[StatutInterventionEnum] = StatutInterventionEnum.EN_ATTENTE
    duree_minutes: Optional[float] = None  # propriété calculée
    rapport: Optional[RapportPanneResponse] = None

    class Config:
        from_attributes = True

    @classmethod
    def from_orm_with_duree(cls, obj):
        """Factory qui inclut la durée calculée"""
        data = cls.from_orm(obj)
        data.duree_minutes = obj.duree  # utilise la @property du modèle
        return data


class InterventionDetailResponse(InterventionResponse):
    """Réponse détaillée avec les relations"""
    technicien: Optional[TechnicienNestedResponse] = None
    panne: Optional[PanneNestedResponse] = None

    class Config:
        from_attributes = True


class TerminerInterventionResponse(BaseModel):
    """Réponse après la terminaison d'une intervention"""
    message: str
    id_intervention: int
    date_debut: datetime
    date_acceptation: Optional[datetime] = None
    date_scan_qr: Optional[datetime] = None
    date_fin: datetime
    duree_minutes: Optional[float] = None
