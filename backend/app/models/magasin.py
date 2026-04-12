from sqlalchemy import Column, Integer, String, DateTime, ForeignKey, Text, Enum as SQLEnum
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base
import enum


class StatutDemandeEnum(str, enum.Enum):
    EN_ATTENTE = "en_attente"
    APPROUVEE = "approuvee"
    REFUSEE = "refusee"
    LIVREE = "livree"


class PieceRechange(Base):
    """Table catalogue du magasin de pièces de rechange"""
    __tablename__ = "piece_rechange"

    id_piece = Column(Integer, primary_key=True, index=True)
    reference = Column(String(100), unique=True, nullable=False, index=True)
    nom = Column(String(200), nullable=False)
    description = Column(Text, nullable=True)
    quantite_stock = Column(Integer, nullable=False, default=0)
    unite = Column(String(20), nullable=False, default="pcs")  # pcs, m, kg, L …
    date_maj = Column(DateTime, nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow)

    # Relations
    demandes = relationship("DemandeRechange", back_populates="piece")


class DemandeRechange(Base):
    """Table des demandes de pièces par les techniciens"""
    __tablename__ = "demande_rechange"

    id_demande = Column(Integer, primary_key=True, index=True)
    id_intervention = Column(Integer, ForeignKey("intervention.id_intervention", ondelete="CASCADE"), nullable=False)
    id_piece = Column(Integer, ForeignKey("piece_rechange.id_piece", ondelete="CASCADE"), nullable=False)
    quantite_demandee = Column(Integer, nullable=False, default=1)
    statut = Column(SQLEnum(StatutDemandeEnum), nullable=False, default=StatutDemandeEnum.EN_ATTENTE)
    commentaire = Column(Text, nullable=True)
    date_demande = Column(DateTime, nullable=False, default=datetime.utcnow)

    # Relations
    intervention = relationship("Intervention", back_populates="demandes_rechange")
    piece = relationship("PieceRechange", back_populates="demandes")
