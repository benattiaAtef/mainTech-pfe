from __future__ import annotations

from app.shema.user import UtilisateurResponse

"""
Schémas Pydantic pour les techniciens
"""
from pydantic import BaseModel, EmailStr, Field
from app.models.enums import StatutTechnicienEnum, RoleEnum


# ============================================
# TECHNICIEN
# ============================================

class CompetenceResponse(BaseModel):
    """Schéma de réponse pour une compétence"""
    id_competence: int
    id_groupe_machine: int
    niveau_expertise: str

    class Config:
        from_attributes = True

class TechnicienBase(BaseModel):
    """Schéma de base pour un technicien"""
    id_groupe_principal: int | None = None
    statut: StatutTechnicienEnum = StatutTechnicienEnum.DISPONIBLE
    position_lat: float | None = Field(None, ge=-90, le=90)
    position_lng: float | None = Field(None, ge=-180, le=180)
    matricule: str | None = Field(None, max_length=50)


class TechnCreate(BaseModel):
    """Schéma pour créer un technicien (avec utilisateur)"""
    # Données utilisateur
    nom: str = Field(..., min_length=1, max_length=100)
    prenom: str = Field(..., min_length=1, max_length=100)
    email: EmailStr
    mot_de_passe: str = Field(..., min_length=8)
    
    # Données technicien
    id_groupe_principal: int | None = None
    statut: StatutTechnicienEnum = StatutTechnicienEnum.DISPONIBLE
    position_lat: float | None = Field(None, ge=-90, le=90)
    position_lng: float | None = Field(None, ge=-180, le=180)
    matricule: str | None = Field(None, max_length=50)
    
    # Liste des IDs de groupes de machines pour lesquels le tech a une compétence (renfort)
    competences_ids: list[int] = []


class TechnicienUpdate(BaseModel):
    """Schéma pour mettre à jour un technicien"""
    id_groupe_principal: int | None = None
    statut: StatutTechnicienEnum | None = None
    position_lat: float | None = Field(None, ge=-90, le=90)
    position_lng: float | None = Field(None, ge=-180, le=180)
    matricule: str | None = Field(None, max_length=50)


class TechnicienResponse(BaseModel):
    """Schéma de réponse API"""
    id_technicien: int
    id_utilisateur: int
    id_groupe_principal: int | None
    statut: StatutTechnicienEnum
    position_lat: float | None
    position_lng: float | None
    matricule: str | None
    
    utilisateur: UtilisateurResponse  # Inclure les données de l'utilisateur lié
    competences: list[CompetenceResponse] = [] # Liste des compétences
    
    # Statistiques journalières
    interventions_count_today: int = 0
    total_time_today_minutes: int = 0
    
    class Config:
        from_attributes = True


class TechnicienAvailable(BaseModel):
    """Technicien disponible avec distance"""
    id_technicien: int
    nom: str
    prenom: str
    statut: StatutTechnicienEnum
    position_lat: float | None
    position_lng: float | None
    distance_km: float | None = None
    temps_libre_minutes: int | None = None


class UpdateStatutRequest(BaseModel):
    """Requête pour changer le statut"""
    statut: StatutTechnicienEnum


from pydantic import BaseModel

class StatutUpdate(BaseModel):
    statut: StatutTechnicienEnum