from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Numeric, Date, Table, JSON, Text
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base
from app.models.enums import TypeAffectationEnum, StatutInterventionEnum




class Intervention(Base):
    """Table Intervention"""
    __tablename__ = "intervention"
    
    id_intervention = Column(Integer, primary_key=True, index=True)
    id_panne = Column(Integer, ForeignKey("panne.id_panne", ondelete="CASCADE"), nullable=False)
    id_technicien = Column(Integer, ForeignKey("technicien.id_technicien", ondelete="CASCADE"), nullable=False)
    date_debut = Column(DateTime, nullable=False, default=datetime.utcnow) # Attribution automatique/manuelle
    date_acceptation = Column(DateTime, nullable=True) # Heure réelle d'acceptation
    date_scan_qr = Column(DateTime, nullable=True) # Heure du scan QR (démarrage réel)
    date_fin = Column(DateTime, nullable=True)
    statut = Column(SQLEnum(StatutInterventionEnum), nullable=False, default=StatutInterventionEnum.EN_ATTENTE)
    type_affectation = Column(SQLEnum(TypeAffectationEnum), nullable=False, default=TypeAffectationEnum.AUTOMATIQUE)
    
    # Relations
    panne = relationship("Panne", back_populates="interventions")
    technicien = relationship("Technicien", back_populates="interventions")
    autorisation = relationship("AutorisationExceptionnelle", back_populates="intervention", uselist=False, cascade="all, delete-orphan")
    rapport = relationship("RapportPanne", back_populates="intervention", uselist=False, cascade="all, delete-orphan")
    demandes_rechange = relationship("DemandeRechange", back_populates="intervention", cascade="all, delete-orphan")
    
    @property
    def duree(self):
        """Calcule la durée en minutes (entre scan QR et fin)"""
        if self.date_fin and self.date_scan_qr:
            return (self.date_fin - self.date_scan_qr).total_seconds() / 60
        return None


class RapportPanne(Base):
    """Table RapportPanne (Bon de Travail)"""
    __tablename__ = "rapport_panne"
    
    id_rapport = Column(Integer, primary_key=True, index=True)
    id_intervention = Column(Integer, ForeignKey("intervention.id_intervention", ondelete="CASCADE"), unique=True, nullable=False)
    
    description_panne = Column(Text, nullable=True)
    travaux_effectues = Column(Text, nullable=True)
    type_travail = Column(String(50), nullable=True) # MCP, MNP, AUT
    codes_defaut = Column(JSON, nullable=True) # {what, why, where}
    pieces_rechange = Column(JSON, nullable=True) # List of {part_name, quantity}
    temps_arret = Column(Integer, nullable=True) # Minutes
    observations = Column(Text, nullable=True)
    
    # Nouveaux champs pour un rapport plus détaillé
    causes = Column(Text, nullable=True)
    solutions = Column(Text, nullable=True)
    etat_final = Column(String(100), nullable=True)
    
    date_rapport = Column(DateTime, default=datetime.utcnow)
    
    # Relations
    intervention = relationship("Intervention", back_populates="rapport")
