from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime


class PieceRechangeCreate(BaseModel):
    reference: str
    nom: str
    description: Optional[str] = None
    quantite_stock: int = Field(default=0, ge=0)
    unite: str = "pcs"


class PieceRechangeUpdate(BaseModel):
    nom: Optional[str] = None
    description: Optional[str] = None
    quantite_stock: Optional[int] = Field(default=None, ge=0)
    unite: Optional[str] = None


class PieceRechangeOut(BaseModel):
    id_piece: int
    reference: str
    nom: str
    description: Optional[str]
    quantite_stock: int
    unite: str
    date_maj: datetime

    class Config:
        from_attributes = True


# ---- Demandes ----

class DemandeRechangeCreate(BaseModel):
    id_intervention: int
    id_piece: int
    quantite_demandee: int = Field(default=1, ge=1)
    commentaire: Optional[str] = None


class DemandeRechangeBatchCreate(BaseModel):
    demandes: list[DemandeRechangeCreate]


class DemandeStatutUpdate(BaseModel):
    statut: str  # en_attente | approuvee | refusee | livree


class DemandeRechangeOut(BaseModel):
    id_demande: int
    id_intervention: int
    id_piece: int
    quantite_demandee: int
    statut: str
    commentaire: Optional[str]
    date_demande: datetime
    piece: Optional[PieceRechangeOut] = None

    class Config:
        from_attributes = True
