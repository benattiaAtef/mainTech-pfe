
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Numeric, Date, Table
from sqlalchemy.orm import relationship, validates
from datetime import datetime
from app.core.database import Base
from app.models.enums import RoleEnum, StatutTechnicienEnum, StatutPresenceEnum


class Utilisateur(Base):
    """Table Utilisateur - Base pour tous les utilisateurs"""
    __tablename__ = "utilisateur"
    
    id_utilisateur = Column(Integer, primary_key=True, index=True)
    nom = Column(String(100), nullable=False)
    prenom = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, index=True, nullable=False)
    mot_de_passe = Column(String(255), nullable=False)
    role = Column(SQLEnum(RoleEnum, values_callable=lambda x: [e.value for e in x]), nullable=False)
    statut_presence = Column(SQLEnum(StatutPresenceEnum, values_callable=lambda x: [e.value for e in x]), nullable=False, default=StatutPresenceEnum.EN_TRAVAIL)

    @validates('role', 'statut_presence')
    def validate_enums(self, key, value):
        """Pass-through validation, allowing the DB or Enum class to handle constraints."""
        return value
    
    # Nouveau champ pour FCM (déplacé ici pour être universel)
    fcm_token = Column(String, nullable=True)  # <-- token Firebase Cloud Messaging

    # Relations
    technicien = relationship("Technicien", back_populates="utilisateur", uselist=False, cascade="all, delete-orphan")
    chef_equipe = relationship("ChefEquipe", back_populates="utilisateur", uselist=False, cascade="all, delete-orphan")
    superviseur = relationship("Superviseur", back_populates="utilisateur", uselist=False, cascade="all, delete-orphan")
    administrateur = relationship("Administrateur", back_populates="utilisateur", uselist=False, cascade="all, delete-orphan")
    magasinier = relationship("Magasinier", back_populates="utilisateur", uselist=False, cascade="all, delete-orphan")


class Technicien(Base):
    __tablename__ = "technicien"
    
    id_technicien = Column(Integer, primary_key=True, index=True)
    id_utilisateur = Column(Integer, ForeignKey("utilisateur.id_utilisateur", ondelete="CASCADE"), nullable=False, unique=True)
    id_groupe_principal = Column(Integer, ForeignKey("groupe_technicien.id_groupe_tech"), nullable=True)
    statut = Column(SQLEnum(StatutTechnicienEnum, values_callable=lambda x: [e.value for e in x]), nullable=False, default=StatutTechnicienEnum.DISPONIBLE)
    position_lat = Column(Numeric(10, 7), nullable=True)
    position_lng = Column(Numeric(10, 7), nullable=True)
    matricule = Column(String(50), unique=True, nullable=True)
    date_dernier_statut = Column(DateTime, nullable=True, default=datetime.utcnow)

    # Relations
    utilisateur = relationship("Utilisateur", back_populates="technicien")
    groupe_principal = relationship("GroupeTechnicien", back_populates="techniciens")
    interventions = relationship("Intervention", back_populates="technicien", cascade="all, delete-orphan")
    competences = relationship("CompetenceTechnicien", back_populates="technicien", cascade="all, delete-orphan")
    statistiques = relationship("StatistiqueTech", back_populates="technicien", cascade="all, delete-orphan")


class ChefEquipe(Base):
    """Table ChefEquipe"""
    __tablename__ = "chef_equipe"
    
    id_chef = Column(Integer, primary_key=True, index=True)
    id_utilisateur = Column(Integer, ForeignKey("utilisateur.id_utilisateur", ondelete="CASCADE"), nullable=False, unique=True)
    id_groupe_supervise = Column(Integer, ForeignKey("groupe_technicien.id_groupe_tech"), nullable=True)
    
    # Relations
    utilisateur = relationship("Utilisateur", back_populates="chef_equipe")
    groupe_supervise = relationship("GroupeTechnicien", back_populates="chef_equipe")
    autorisations = relationship("AutorisationExceptionnelle", back_populates="chef_equipe")


class Superviseur(Base):
    """Table Superviseur"""
    __tablename__ = "superviseur"
    
    id_superviseur = Column(Integer, primary_key=True, index=True)
    id_utilisateur = Column(Integer, ForeignKey("utilisateur.id_utilisateur", ondelete="CASCADE"), nullable=False, unique=True)
    zone_responsabilite = Column(String(255), nullable=True)
    
    # Relations
    utilisateur = relationship("Utilisateur", back_populates="superviseur")
    pannes_creees = relationship("Panne", back_populates="superviseur")


class Administrateur(Base):
    """Table Administrateur"""
    __tablename__ = "administrateur"
    
    id_admin = Column(Integer, primary_key=True, index=True)
    id_utilisateur = Column(Integer, ForeignKey("utilisateur.id_utilisateur", ondelete="CASCADE"), nullable=False, unique=True)
    niveau_acces = Column(String(50), nullable=False, default="admin")
    
    # Relations
    utilisateur = relationship("Utilisateur", back_populates="administrateur")


class Magasinier(Base):
    """Table Magasinier"""
    __tablename__ = "magasinier"
    
    id_magasinier = Column(Integer, primary_key=True, index=True)
    id_utilisateur = Column(Integer, ForeignKey("utilisateur.id_utilisateur", ondelete="CASCADE"), nullable=False, unique=True)
    
    # Relations
    utilisateur = relationship("Utilisateur", back_populates="magasinier")