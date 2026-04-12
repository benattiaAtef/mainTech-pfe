"""
Service de Notification - Système LEONI
Stratégie hybride :
  • App OUVERTE  → WebSocket (temps réel, instantané)
  • App FERMÉE   → Firebase FCM (push notification)
  • Les deux envoyés en parallèle pour garantie de livraison
"""

import logging
import httpx
from typing import Optional, Any
from datetime import datetime

logger = logging.getLogger(__name__)

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION FCM — mettre dans .env : FCM_SERVER_KEY=votre_clé_firebase
# ─────────────────────────────────────────────────────────────────────────────
import os
FCM_SERVER_KEY = os.getenv("FCM_SERVER_KEY", "")
FCM_URL = "https://fcm.googleapis.com/fcm/send"

GRAVITE_COLORS = {
    "critique": "#FF0000",
    "haute":    "#FF6600",
    "moyenne":  "#FFA500",
    "faible":   "#00AA00",
}

GRAVITE_ICONS = {
    "critique": "🔴",
    "haute":    "🟠",
    "moyenne":  "🟡",
    "faible":   "🟢",
}


# ══════════════════════════════════════════════════════════════════════════════
# GESTIONNAIRE WEBSOCKET
# ══════════════════════════════════════════════════════════════════════════════

class WebSocketManager:
    """Gère les connexions WebSocket actives par ID utilisateur (Technicien, Chef, etc.)"""

    def __init__(self):
        self.connections: dict[int, list] = {}

    async def connect(self, websocket, user_id: int):
        await websocket.accept()
        self.connections.setdefault(user_id, []).append(websocket)
        logger.info(f"[WS] Utilisateur {user_id} connecté")

    def disconnect(self, websocket, user_id: int):
        sockets = self.connections.get(user_id, [])
        if websocket in sockets:
            sockets.remove(websocket)
        if not sockets:
            self.connections.pop(user_id, None)
        logger.info(f"[WS] Utilisateur {user_id} déconnecté")

    def is_connected(self, user_id: int) -> bool:
        return bool(self.connections.get(user_id))

    async def send(self, user_id: int, payload: dict) -> bool:
        sockets = self.connections.get(user_id, [])
        if not sockets:
            return False
        dead, sent = [], False
        for ws in sockets:
            try:
                await ws.send_json(payload)
                sent = True
            except Exception as e:
                logger.warning(f"[WS] Socket mort utilisateur {user_id}: {e}")
                dead.append(ws)
        for ws in dead:
            sockets.remove(ws)
        return sent

ws_manager = WebSocketManager()



# ══════════════════════════════════════════════════════════════════════════════
# SERVICE FCM
# ══════════════════════════════════════════════════════════════════════════════

async def envoyer_fcm(
    fcm_token: str,
    titre: str,
    corps: str,
    data: dict,
    gravite: str = "moyenne",
) -> bool:
    """
    Envoie une push notification Firebase FCM à l'appareil Flutter.
    
    Le technicien reçoit la notif même si l'app est fermée.
    Flutter reçoit le 'data' payload dans onBackgroundMessage().
    """
    if not FCM_SERVER_KEY:
        logger.error("[FCM] FCM_SERVER_KEY manquante dans .env !")
        return False
    if not fcm_token:
        logger.warning("[FCM] Token FCM vide - notification ignorée")
        return False

    color = GRAVITE_COLORS.get(gravite, "#FFA500")
    icon  = GRAVITE_ICONS.get(gravite, "🔧")

    payload = {
        "to": fcm_token,
        "priority": "high",
        "notification": {
            "title": f"{icon} {titre}",
            "body": corps,
            "sound": "default",
            "color": color,
            "android_channel_id": "leoni_pannes",
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
        },
        "data": {
            **{k: str(v) for k, v in data.items()},
            "gravite": gravite,
            "color": color,
        },
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            resp = await client.post(
                FCM_URL,
                json=payload,
                headers={
                    "Authorization": f"key={FCM_SERVER_KEY}",
                    "Content-Type": "application/json",
                },
            )
            result = resp.json()
            if resp.status_code == 200 and result.get("success") == 1:
                logger.info(f"[FCM] ✅ Envoyé - {result.get('results')}")
                return True
            else:
                logger.error(f"[FCM] ❌ Échec: {result}")
                return False
    except Exception as e:
        logger.error(f"[FCM] Erreur: {e}")
        return False


# ══════════════════════════════════════════════════════════════════════════════
# NOTIFICATION PRINCIPALE (WS + FCM)
# ══════════════════════════════════════════════════════════════════════════════

async def notifier_technicien_panne(
    technicien_id: int,
    technicien_nom: str,
    panne_id: int,
    machine_nom: str,
    machine_localisation: str,
    type_panne: str,
    gravite: str,
    priorite: int,
    type_affectation: str = "automatique",
    fcm_token: Optional[str]=None,
    db_session: Optional[Any] = None  # Ajouté pour récupérer id_utilisateur
) -> dict:
    """
    Stratégie hybride :
      1. FCM → toujours envoyé (garantie livraison hors ligne)
      2. WebSocket → si l'app est ouverte (temps réel)
    """
    # Récupérer l'id_utilisateur pour le WebSocket
    user_id = None
    if db_session:
        from app.models.users import Technicien
        tech = db_session.query(Technicien).filter(Technicien.id_technicien == technicien_id).first()
        if tech:
            user_id = tech.id_utilisateur
    
    # Fallback si pas de db_session : on tente avec technicien_id (pour compatibilité temporaire)
    user_id = user_id or technicien_id

    timestamp = datetime.utcnow().isoformat()

    ws_payload = {
        "type": "NOUVELLE_AFFECTATION",
        "timestamp": timestamp,
        "data": {
            "id_panne": panne_id,
            "machine_nom": machine_nom,
            "machine_localisation": machine_localisation,
            "type_panne": type_panne,
            "gravite": gravite,
            "priorite": priorite,
            "type_affectation": type_affectation,
        },
    }

    titre = f"Nouvelle intervention - {machine_nom}"
    corps = f"Type: {type_panne} | Priorité: {priorite}"

    # 1. WebSocket (app ouverte)
    ws_sent = False
    if ws_manager.is_connected(user_id):
        ws_sent = await ws_manager.send(user_id, ws_payload)

    # 2. FCM
    fcm_token_to_use = fcm_token
    if not fcm_token_to_use and db_session:
        # Tenter de récupérer le token depuis l'utilisateur lié
        tech = db_session.query(Technicien).filter(Technicien.id_technicien == technicien_id).first()
        if tech and tech.utilisateur and tech.utilisateur.fcm_token:
            fcm_token_to_use = tech.utilisateur.fcm_token

    fcm_sent = await envoyer_fcm(
        fcm_token=fcm_token_to_use or "",
        titre=titre,
        corps=corps,
        data={
            "type": "NOUVELLE_AFFECTATION",
            "id_panne": str(panne_id),
            "machine_nom": machine_nom,
            "machine_localisation": machine_localisation,
            "type_panne": type_panne,
            "gravite": gravite,
            "priorite": str(priorite),
        },
        gravite=gravite,
    )

    logger.info(
        f"Notif panne {panne_id} → tech {technicien_id} | "
        f"WS={'✅' if ws_sent else '❌'} FCM={'✅' if fcm_sent else '❌'}"
    )

    return {
        "technicien_id": technicien_id,
        "technicien_nom": technicien_nom,
        "websocket_envoye": ws_sent,
        "fcm_envoye": fcm_sent,
        "notification_status": (
            "temps_reel_et_push" if (ws_sent and fcm_sent)
            else "temps_reel" if ws_sent
            else "push" if fcm_sent
            else "echec"
        ),
    }


async def notifier_superviseur(
    superviseur_id: int,
    panne_id: int,
    technicien_nom: str,
    machine_nom: str,
    fcm_token: Optional[str] = None,
) -> bool:
    payload = {
        "type": "PANNE_AFFECTEE",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {
            "id_panne": panne_id,
            "machine": machine_nom,
            "technicien_affecte": technicien_nom,
        },
    }
    ws_sent = await ws_manager.send(superviseur_id, payload)
    if fcm_token:
        await envoyer_fcm(
            fcm_token=fcm_token,
            titre=f"✅ Panne #{panne_id} affectée",
            corps=f"{technicien_nom} assigné sur {machine_nom}",
            data={"type": "PANNE_AFFECTEE", "id_panne": str(panne_id)},
            gravite="faible",
        )
async def notifier_chef_equipe_autorisation(
    chef_id: int, # id_utilisateur du chef
    panne_id: int,
    technicien_nom: str,
    fcm_token: Optional[str] = None,
    db_session: Optional[Any] = None
) -> dict:
    payload = {
        "type": "DEMANDE_AUTORISATION",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {
            "id_panne": panne_id,
            "technicien_nom": technicien_nom,
        },
    }
    ws_sent = await ws_manager.send(chef_id, payload)
    print(f"[DEBUG_NOTIF] Notifier Chef {chef_id} | Panne {panne_id} | WS={ws_sent}")
    
    # 2. FCM
    fcm_token_to_use = fcm_token
    if not fcm_token_to_use and db_session:
        from app.models.users import Utilisateur
        user = db_session.query(Utilisateur).filter(Utilisateur.id_utilisateur == chef_id).first()
        if user and user.fcm_token:
            fcm_token_to_use = user.fcm_token

    fcm_sent = False
    if fcm_token_to_use:
        fcm_sent = await envoyer_fcm(
            fcm_token=fcm_token_to_use,
            titre=f"⚠️ Autorisation requise - Panne #{panne_id}",
            corps=f"L'affectation de {technicien_nom} attend votre aval.",
            data={"type": "DEMANDE_AUTORISATION", "id_panne": str(panne_id)},
            gravite="haute",
        )
    print(f"[DEBUG_NOTIF] FCM for Chef {chef_id} | Sent={fcm_sent}")
    return {
        "websocket_envoye": ws_sent,
        "fcm_envoye": fcm_sent
    }
