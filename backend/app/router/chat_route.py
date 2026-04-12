from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

from app.core.database import get_db
from app.core.security import require_role
from app.models.enums import RoleEnum, StatutPresenceEnum
from app.models.chat import ChatMessage
from app.models.users import Utilisateur, Technicien, ChefEquipe
from app.shema.chat_shema import ChatMessageCreate, ChatMessageResponse
from app.utils import notification_manager

router_chat = APIRouter(prefix="/chat", tags=["Chat"])

@router_chat.get("/{id_groupe}", response_model=List[ChatMessageResponse])
def get_chat_history(
    id_groupe: int,
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db),
    current_user = Depends(require_role(RoleEnum.TECHNICIEN, RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR))
):
    """Récupérer l'historique du chat pour un groupe"""
    messages = db.query(ChatMessage).filter(
        ChatMessage.id_groupe == id_groupe
    ).order_by(ChatMessage.date_envoi.desc()).limit(limit).all()
    
    # Inverser pour avoir l'ordre chronologique
    messages.reverse()
    
    response = []
    for msg in messages:
        response.append(ChatMessageResponse(
            id_message=msg.id_message,
            id_expediteur=msg.id_expediteur,
            id_groupe=msg.id_groupe,
            contenu=msg.contenu,
            date_envoi=msg.date_envoi,
            expediteur_nom=msg.expediteur.nom,
            expediteur_prenom=msg.expediteur.prenom
        ))
    return response

@router_chat.post("/{id_groupe}", response_model=ChatMessageResponse)
async def send_message(
    id_groupe: int,
    msg_data: ChatMessageCreate,
    db: Session = Depends(get_db),
    current_user = Depends(require_role(RoleEnum.TECHNICIEN, RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR))
):
    """Envoyer un message au groupe et notifier les membres"""
    if current_user.statut_presence != StatutPresenceEnum.EN_TRAVAIL:
        raise HTTPException(
            status_code=403,
            detail="Seuls les utilisateurs 'En travail' peuvent envoyer des messages."
        )

    # 1. Sauvegarder en base
    nouveau_msg = ChatMessage(
        id_expediteur=current_user.id_utilisateur,
        id_groupe=id_groupe,
        contenu=msg_data.contenu
    )
    db.add(nouveau_msg)
    db.commit()
    db.refresh(nouveau_msg)
    
    # 2. Notifier les membres du groupe via WebSocket (broadcast)
    # Chercher les membres (Techniciens + Chef d'équipe)
    techniciens = db.query(Technicien).filter(Technicien.id_groupe_principal == id_groupe).all()
    chef = db.query(ChefEquipe).filter(ChefEquipe.id_groupe_supervise == id_groupe).first()
    
    # Liste des IDs utilisateurs à notifier
    user_ids = [t.id_utilisateur for t in techniciens]
    if chef:
        user_ids.append(chef.id_utilisateur)
        
    # Payload pour le broadcast
    payload = {
        "type": "CHAT_MESSAGE",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {
            "id_message": nouveau_msg.id_message,
            "id_expediteur": current_user.id_utilisateur,
            "expediteur_nom": current_user.nom,
            "expediteur_prenom": current_user.prenom,
            "id_groupe": id_groupe,
            "contenu": nouveau_msg.contenu,
            "date_envoi": nouveau_msg.date_envoi.isoformat()
        }
    }
    
    # Envoyer à tout le monde (sauf l'expéditeur ?) - Non, envoyer à tout le monde pour synchro UI simplifiée
    for u_id in user_ids:
        await notification_manager.ws_manager.send(u_id, payload)
        
    return ChatMessageResponse(
        id_message=nouveau_msg.id_message,
        id_expediteur=nouveau_msg.id_expediteur,
        id_groupe=nouveau_msg.id_groupe,
        contenu=nouveau_msg.contenu,
        date_envoi=nouveau_msg.date_envoi,
        expediteur_nom=current_user.nom,
        expediteur_prenom=current_user.prenom
    )

@router_chat.post("/call-signal")
async def send_call_signal(
    receiver_id: int,
    signal_type: str, # INITIATE, ACCEPT, REJECT, END
    is_video: bool = False,
    current_user = Depends(require_role(RoleEnum.TECHNICIEN, RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR))
):
    """Signaler un appel via WebSocket (Signaling)"""
    payload = {
        "type": "CALL_SIGNAL",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {
            "caller_id": current_user.id_utilisateur,
            "caller_nom": current_user.nom,
            "caller_prenom": current_user.prenom,
            "signal_type": signal_type.upper(),
            "is_video": is_video
        }
    }
    
    # Envoyer au destinataire
    success = await notification_manager.ws_manager.send(receiver_id, payload)
    
    if not success:
        # Tenter via le manager de notification global si c'est un technicien
        # (Pour l'instant on se fie au WebSocket actif)
        pass
        
    return {"status": "success", "signaled": success}
