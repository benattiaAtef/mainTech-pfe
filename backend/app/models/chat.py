from sqlalchemy import Column, Integer, String, DateTime, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.core.database import Base

class ChatMessage(Base):
    """Table ChatMessage - Messages d'équipe"""
    __tablename__ = "chat_message"
    
    id_message = Column(Integer, primary_key=True, index=True)
    id_expediteur = Column(Integer, ForeignKey("utilisateur.id_utilisateur", ondelete="CASCADE"), nullable=False)
    id_groupe = Column(Integer, ForeignKey("groupe_technicien.id_groupe_tech", ondelete="CASCADE"), nullable=False)
    contenu = Column(String, nullable=False)
    date_envoi = Column(DateTime, default=datetime.utcnow)
    
    # Relations
    expediteur = relationship("Utilisateur")
    groupe = relationship("GroupeTechnicien")
