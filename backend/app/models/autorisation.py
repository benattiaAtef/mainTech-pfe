
from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Numeric, Date, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base
from app.models.enums import StatutAutorisationEnum






class AutorisationExceptionnelle(Base):
    """Table AutorisationExceptionnelle"""
    __tablename__ = "autorisation_exceptionnelle"
    
    id_autorisation = Column(Integer, primary_key=True, index=True)
    id_intervention = Column(Integer, ForeignKey("intervention.id_intervention", ondelete="CASCADE"), nullable=False)
    id_chef_equipe = Column(Integer, ForeignKey("chef_equipe.id_chef"), nullable=False)
    statut = Column(SQLEnum(StatutAutorisationEnum), nullable=False, default=StatutAutorisationEnum.EN_ATTENTE)
    
    # Relations
    intervention = relationship("Intervention", back_populates="autorisation")
    chef_equipe = relationship("ChefEquipe", back_populates="autorisations")


class StatistiqueTech(Base):
    """Table StatistiqueTech"""
    __tablename__ = "statistique_tech"
    
    id_statistique = Column(Integer, primary_key=True, index=True)
    id_technicien = Column(Integer, ForeignKey("technicien.id_technicien", ondelete="CASCADE"), nullable=False)
    nombreintervention = Column(Integer, nullable=False, default=0)
    temps_moyen_intervention = Column(Numeric(10, 2), nullable=True)
    taux_reussite = Column(Numeric(5, 2), nullable=True)
    
    # Relations
    technicien = relationship("Technicien", back_populates="statistiques")