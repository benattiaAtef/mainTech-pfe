from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Enum as SQLEnum, Numeric, Date, Table, func
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base
from app.models.enums import GraviteEnum, StatutPanneEnum





class TypePanne(Base):
    """Table TypePanne"""
    __tablename__ = "type_panne"
    
    id_type_panne = Column(Integer, primary_key=True, index=True)
    nom_panne = Column(String(100), nullable=False, unique=True)
    gravite = Column(SQLEnum(GraviteEnum, values_callable=lambda x: [e.value for e in x]), nullable=False, default=GraviteEnum.MOYENNE)
    
    # Relations
    pannes = relationship("Panne", back_populates="type_panne")


class Panne(Base):
    """Table Panne"""
    __tablename__ = "panne"
    
    id_panne = Column(Integer, primary_key=True, index=True)
    id_machine = Column(Integer, ForeignKey("machine.id_machine", ondelete="CASCADE"), nullable=False)
    id_type_panne = Column(Integer, ForeignKey("type_panne.id_type_panne"), nullable=False)
    id_superviseur = Column(Integer, ForeignKey("superviseur.id_superviseur"), nullable=False)
    priorite = Column(Integer, nullable=False, default=3)
    gravite = Column(SQLEnum(GraviteEnum, values_callable=lambda x: [e.value for e in x]), nullable=True)
    statut = Column(SQLEnum(StatutPanneEnum, values_callable=lambda x: [e.value for e in x]), nullable=False, default=StatutPanneEnum.EN_ATTENTE)
    date_declaration = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relations
    machine = relationship("Machine", back_populates="pannes")
    type_panne = relationship("TypePanne", back_populates="pannes")
    superviseur = relationship("Superviseur", back_populates="pannes_creees")
    interventions = relationship("Intervention", back_populates="panne", cascade="all, delete-orphan")


class HistoriquePanne(Base):
    """Table HistoriquePanne"""
    __tablename__ = "historique_panne"
    
    id_panne = Column(Integer, ForeignKey("panne.id_panne", ondelete="CASCADE"), primary_key=True)
    id_type_panne = Column(Integer, ForeignKey("type_panne.id_type_panne"), nullable=False)
    id_machine = Column(Integer, ForeignKey("machine.id_machine", ondelete="CASCADE"), nullable=False)
    frequence_panne = Column(Numeric(5, 2), nullable=True)
    dernie_panne = Column(Date, nullable=True)
    
    # Relations
    panne = relationship("Panne")
    type_panne = relationship("TypePanne")
    machine = relationship("Machine", back_populates="historiques")

