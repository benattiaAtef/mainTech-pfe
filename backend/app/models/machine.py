from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Numeric, Date, Table
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base




class GroupeMachine(Base):
    """Table GroupeMachine"""
    __tablename__ = "groupe_machine"
    
    id_groupe_machine = Column(Integer, primary_key=True, index=True)
    nom_groupe = Column(String(100), nullable=False, unique=True)
    niveau_priorite = Column(Integer, nullable=False, default=1)
    id_groupe_tech_principal = Column(Integer, ForeignKey("groupe_technicien.id_groupe_tech"), nullable=True)
    
    # Relations
    groupe_tech_principal = relationship("GroupeTechnicien")
    machines = relationship("Machine", back_populates="groupe_machine", cascade="all, delete-orphan")
    competences_requises = relationship("CompetenceTechnicien", back_populates="groupe_machine")


class Machine(Base):
    """Table Machine"""
    __tablename__ = "machine"
    
    id_machine = Column(Integer, primary_key=True, index=True)
    nom = Column(String(100), nullable=False)
    id_groupe_machine = Column(Integer, ForeignKey("groupe_machine.id_groupe_machine"), nullable=False)
    qr_code = Column(String(255), unique=True, nullable=False, index=True)
    localisation = Column(String(255), nullable=False)
    num_serie = Column(String(100), nullable=True)
    date_installation = Column(DateTime, nullable=True)
    fonction = Column(String(255), nullable=True)
    
    # Relations
    groupe_machine = relationship("GroupeMachine", back_populates="machines")
    pannes = relationship("Panne", back_populates="machine", cascade="all, delete-orphan")
    historiques = relationship("HistoriquePanne", back_populates="machine", cascade="all, delete-orphan")