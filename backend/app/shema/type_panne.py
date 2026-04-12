from pydantic import BaseModel, Field
from typing import Optional
from app.models.enums import GraviteEnum


# ─────────────────────────────────────────────
#  CREATE
# ─────────────────────────────────────────────

class TypePanneCreate(BaseModel):
    """Créer un nouveau type de panne"""
    nom_panne: str = Field(
        ...,
        min_length=2,
        max_length=100,
        description="Nom unique du type de panne"
    )
    gravite: GraviteEnum = Field(
        default=GraviteEnum.MOYENNE,
        description="Niveau de gravité : faible, moyenne, haute, critique"
    )

    class Config:
        use_enum_values = True


# ─────────────────────────────────────────────
#  UPDATE
# ─────────────────────────────────────────────

class TypePanneUpdate(BaseModel):
    """Modifier un type de panne existant (tous les champs optionnels)"""
    nom_panne: Optional[str] = Field(
        default=None,
        min_length=2,
        max_length=100,
        description="Nouveau nom"
    )
    gravite: Optional[GraviteEnum] = Field(
        default=None,
        description="Nouveau niveau de gravité"
    )

    class Config:
        use_enum_values = True


# ─────────────────────────────────────────────
#  RESPONSES
# ─────────────────────────────────────────────

class TypePanneResponse(BaseModel):
    """Réponse standard d'un type de panne"""
    id_type_panne: int
    nom_panne: str
    gravite: GraviteEnum

    class Config:
        from_attributes = True


class TypePanneWithCountResponse(TypePanneResponse):
    """Réponse enrichie avec le nombre de pannes associées"""
    nombre_pannes: int = 0

    class Config:
        from_attributes = True