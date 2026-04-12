from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Numeric, Date, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base
from app.models.enums import NiveauExpertiseEnum






class GroupeTechnicien(Base):
    """Table GroupeTechnicien"""
    __tablename__ = "groupe_technicien"
    
    id_groupe_tech = Column(Integer, primary_key=True, index=True)
    nom_groupe = Column(String(100), nullable=False, unique=True)
    nombre_min_dispo = Column(Integer, nullable=False, default=1)
    
    # Relations
    techniciens = relationship("Technicien", back_populates="groupe_principal")
    chef_equipe = relationship("ChefEquipe", back_populates="groupe_supervise", uselist=False)


class CompetenceTechnicien(Base):
    """Table CompetenceTechnicien"""
    __tablename__ = "competence_technicien"
    
    id_competence = Column(Integer, primary_key=True, index=True)
    id_technicien = Column(Integer, ForeignKey("technicien.id_technicien", ondelete="CASCADE"), nullable=False)
    id_groupe_machine = Column(Integer, ForeignKey("groupe_machine.id_groupe_machine"), nullable=False)
    niveau_expertise = Column(SQLEnum(NiveauExpertiseEnum), nullable=False, default=NiveauExpertiseEnum.INTERMEDIAIRE)
    
    # Relations
    technicien = relationship("Technicien", back_populates="competences")
    groupe_machine = relationship("GroupeMachine", back_populates="competences_requises")