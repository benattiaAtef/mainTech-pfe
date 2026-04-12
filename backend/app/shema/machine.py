from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime


class MachineBase(BaseModel):
    nom: str = Field(..., min_length=2, max_length=100)
    qr_code: str = Field(..., min_length=5, max_length=100)
    id_groupe_machine: int
    localisation: Optional[str] = Field(None, max_length=255)
    num_serie: Optional[str] = None
    date_installation: Optional[datetime] = None
    fonction: Optional[str] = None


class MachineCreate(MachineBase):
    pass


class MachineUpdate(BaseModel):
    nom: Optional[str] = Field(None, min_length=2, max_length=100)
    qr_code: Optional[str] = Field(None, min_length=5, max_length=100)
    id_groupe_machine: Optional[int] = None
    localisation: Optional[str] = Field(None, max_length=255)
    num_serie: Optional[str] = None
    date_installation: Optional[datetime] = None
    fonction: Optional[str] = None


class MachineResponse(BaseModel):
    id_machine: int
    nom: str
    qr_code: str
    localisation: str
    id_groupe_machine: int
    
    groupe_nom: Optional[str] = None
    nombre_pannes_total: Optional[int] = 0
    derniere_panne: Optional[datetime] = None
    statut: Optional[str] = "Opérationnel"
    
    num_serie: Optional[str] = None
    date_installation: Optional[datetime] = None
    fonction: Optional[str] = None
    id_groupe_tech_principal: Optional[int] = None

    class Config:
        from_attributes = True


class Qrcode(BaseModel):
    qrcode: str