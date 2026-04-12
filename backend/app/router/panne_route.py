

import asyncio
import json
from datetime import datetime

from sqlalchemy.orm import Session

import logging
from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.params import Query

logger = logging.getLogger(__name__)

from app.core.database import get_db
from app.core.security import require_role
from app.models.enums import RoleEnum, StatutPanneEnum, StatutTechnicienEnum, TypeAffectationEnum, StatutInterventionEnum, GraviteEnum, StatutAutorisationEnum
from app.models.intervention import Intervention
from app.models.machine import Machine, GroupeMachine
from app.models.panne import Panne, TypePanne
from app.models.users import Superviseur, Utilisateur, ChefEquipe
from app.models.autorisation import AutorisationExceptionnelle
from app.shema.panne import PanneCreate, PanneDetailResponse, PanneResponse
from app.utils import notification_manager
from app.utils.panne_util import selectionner_technicien_optimal


router_panne = APIRouter(prefix="/pannes", tags=["Pannes"])


@router_panne.get("/", response_model=list[PanneResponse], summary="Lister toutes les pannes")
def lister_pannes(
    skip:  int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db),
):
    query = db.query(Panne)
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            query = query.join(Machine).join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
        else:
            return []
            
    return query.offset(skip).limit(limit).all()


@router_panne.get(
    "/en-attente",
    response_model=list[PanneResponse],
    summary="Pannes EN_ATTENTE triées par priorité",
)
def pannes_en_attente(
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR, RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db)
):
    query = db.query(Panne).filter(Panne.statut == StatutPanneEnum.EN_ATTENTE)
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            query = query.join(Machine).join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
        else:
            return []

    return query.order_by(Panne.priorite.asc()).all()


@router_panne.get(
    "/statut/{statut}",
    response_model=list[PanneResponse],
    summary="Filtrer par statut",
)
def pannes_par_statut(
    statut: StatutPanneEnum, 
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR, RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db)
):
    query = db.query(Panne).filter(Panne.statut == statut)
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            query = query.join(Machine).join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
        else:
            return []
            
    return query.all()


@router_panne.get(
    "/machine/{id_machine}",
    response_model=list[PanneResponse],
    summary="Pannes d'une machine",
)
def pannes_par_machine(
    id_machine: int, 
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR, RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db)
):
    query = db.query(Panne).filter(Panne.id_machine == id_machine)
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            query = query.join(Machine).join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
        else:
            return []
            
    return query.all()


@router_panne.get(
    "/superviseur/{id_superviseur}",
    response_model=list[PanneResponse],
    summary="Pannes déclarées par un superviseur",
)
def pannes_par_superviseur(
    id_superviseur: int, 
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db)
):
    query = db.query(Panne).filter(Panne.id_superviseur == id_superviseur)
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            query = query.join(Machine).join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
        else:
            return []
            
    return query.all()



@router_panne.get("/{id_panne}", response_model=PanneResponse, summary="Détail d'une panne")
def obtenir_panne(
    id_panne: int, 
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR, RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db)
):
    panne = db.query(Panne).filter(Panne.id_panne == id_panne).first()
    if not panne:
        raise HTTPException(status_code=404, detail=f"Panne id={id_panne} introuvable.")
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            # Vérifier si la machine appartient au groupe du chef
            if panne.machine.groupe_machine.id_groupe_tech_principal != chef.id_groupe_supervise:
                raise HTTPException(status_code=403, detail="Accès refusé à cette panne")
        else:
            raise HTTPException(status_code=403, detail="Accès refusé")

    return panne


@router_panne.put("/{id_panne}/valider", response_model=PanneResponse, summary="Valider une panne terminée")
def valider_panne(
    id_panne: int,
    current_user=Depends(require_role(RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db)
):
    """🔒 CHEF_EQUIPE, ADMIN - Valider une panne terminée par un technicien"""
    panne = db.query(Panne).filter(Panne.id_panne == id_panne).first()
    if not panne:
        raise HTTPException(status_code=404, detail="Panne introuvable")
    
    # Isolation pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or panne.machine.groupe_machine.id_groupe_tech_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Non autorisé à valider cette panne")

    if panne.statut != StatutPanneEnum.A_VALIDER:
        raise HTTPException(status_code=400, detail=f"La panne est en statut {panne.statut.value}. Seules les pannes 'a_valider' peuvent être validées.")

    panne.statut = StatutPanneEnum.RESOLUE
    db.commit()
    db.refresh(panne)
    return panne




@router_panne.websocket("/ws/{user_id}")
async def websocket_technicien(websocket: WebSocket, user_id: int):
    """
    WS pour tous les utilisateurs (Technicien, Chef, etc.).
    Connexion : ws://host/pannes/ws/{user_id}?token=VOTRE_JWT
    """
    # 🔹 Auth : accepter JWT réel OU token legacy pour compatibilité
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=1008)
        return

    # Vérifier JWT réel d'abord
    from app.core.security import decode_token
    token_data = decode_token(token)
    
    # Fallback sur le token hardcodé pour compatibilité dev (à supprimer en prod)
    if token_data is None and token != "TOKEN_SUPER_SECRET":
        await websocket.close(code=1008)
        return

    try:
        # Connexion
        await notification_manager.ws_manager.connect(websocket, user_id)
        await websocket.send_json({
            "type": "CONNEXION_OK",
            "message": f"Utilisateur {user_id} connecté. En attente de notifications...",
            "timestamp": datetime.utcnow().isoformat(),
        })

        # Boucle de réception
        while True:
            data = await websocket.receive_text()
            
            # Gestion des messages JSON (WebRTC signaling, etc.)
            try:
                message = json.loads(data)
                msg_type = message.get("type")
                
                if msg_type == "SIGNALING":
                    target_id = message.get("target_id")
                    payload = message.get("data")
                    if target_id:
                        # Router le signal vers le destinataire
                        await notification_manager.ws_manager.send(target_id, {
                            "type": "SIGNALING",
                            "from_id": user_id,
                            "data": payload
                        })
                
                # Réponse aux pings ou autres messages JSON
                elif msg_type == "ping":
                    await websocket.send_json({"type": "pong", "timestamp": datetime.utcnow().isoformat()})

            except json.JSONDecodeError:
                # Fallback pour messages texte simples (ping legacy)
                if data == "ping":
                    await websocket.send_text("pong")
                else:
                    logger.warning(f"Message non JSON reçu: {data}")

    except WebSocketDisconnect:
        logger.info(f"[WS] Déconnexion utilisateur {user_id}")
        notification_manager.ws_manager.disconnect(websocket, user_id)
    except Exception as e:
        logger.error(f"[WS] Erreur pour utilisateur {user_id}: {e}")
        await websocket.close(code=1011)
        notification_manager.ws_manager.disconnect(websocket, user_id)


@router_panne.post(
    "/create",
    response_model=PanneDetailResponse,
    summary="Déclarer une panne (affectation auto + notification technicien)",
)
async def creer_panne(
    panne_data: PanneCreate,
    current_user=Depends(require_role(RoleEnum.SUPERVISEUR, RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """
    🔒 SUPERVISEUR, ADMIN

    Workflow complet :
    1. Vérifie machine et type de panne
    2. Crée la panne en base (statut EN_ATTENTE)
    3. Sélectionne automatiquement le meilleur technicien disponible
    4. Crée l'intervention et met à jour le statut du technicien
    5. Envoie une notification WebSocket au technicien
    6. Notifie le superviseur (confirmation)
    7. Retourne la panne avec les détails d'affectation
    """

    # ── 1. Vérifications ──────────────────────────────────────────────────────
    if panne_data.id_machine:
        machine = db.query(Machine).filter(Machine.id_machine == panne_data.id_machine).first()
    elif panne_data.qr_code:
        scanned_value = panne_data.qr_code.strip()
        # 1. Recherche exacte (insensible à la casse)
        machine = db.query(Machine).filter(Machine.qr_code.ilike(scanned_value)).first()
        
        # 2. Recherche par sous-chaîne bidirectionnelle si pas de match exact
        if not machine:
            all_machines = db.query(Machine).all()
            for m in all_machines:
                m_qr = (m.qr_code or "").lower()
                s_val = scanned_value.lower()
                if s_val in m_qr or m_qr in s_val:
                    machine = m
                    break
    else:
        raise HTTPException(status_code=400, detail="id_machine ou qr_code doit être fourni")

    if not machine:
        logger.warning(f"Création panne échouée : QR '{panne_data.qr_code}' non trouvé.")
        raise HTTPException(status_code=404, detail=f"Machine introuvable pour le code : {panne_data.qr_code}")

    type_panne = db.query(TypePanne).filter(
        TypePanne.id_type_panne == panne_data.id_type_panne
    ).first()
    if not type_panne:
        raise HTTPException(status_code=404, detail="Type de panne introuvable")

    # Récupérer l'id_superviseur depuis le user connecté
    superviseur = db.query(Superviseur).filter(
        Superviseur.id_utilisateur == current_user.id_utilisateur
    ).first()
    
    # Si l'admin ou le chef d'équipe crée la panne, on prend le premier superviseur disponible
    if not superviseur and (current_user.role == RoleEnum.ADMINISTRATEUR or current_user.role == RoleEnum.CHEF_EQUIPE):
        superviseur = db.query(Superviseur).first()
    
    if not superviseur:
        raise HTTPException(
            status_code=403,
            detail="Impossible de déterminer un superviseur pour cette panne"
        )

    # ── 2. Calculer la priorité par rareté ou gravité (LEONI 4.5) ─────────────
    # Si une gravité est fournie, elle définit la priorité
    if panne_data.gravite:
        gravity_map = {
            GraviteEnum.CRITIQUE: 1,
            GraviteEnum.HAUTE: 2,
            GraviteEnum.MOYENNE: 3,
            GraviteEnum.FAIBLE: 4
        }
        priorite_calculée = gravity_map.get(panne_data.gravite, 3)
    else:
        # Sinon, plus le nombre de machines du même groupe est faible, plus la priorité est haute
        nb_machines_meme_groupe = db.query(Machine).filter(
            Machine.id_groupe_machine == machine.id_groupe_machine
        ).count()
        
        # Règle simple : Priorité = nb_machines (plus petit = plus prioritaire)
        # On peut aussi saturer à 1 (max)
        priorite_calculée = max(1, nb_machines_meme_groupe)
        if machine.groupe_machine and machine.groupe_machine.nom_groupe == "X":
            priorite_calculée = 1 # Priorité maximale forcée pour le Groupe X (critique)

    # ── 3. Créer la panne ─────────────────────────────────────────────────────
    nouvelle_panne = Panne(
        id_machine=machine.id_machine,
        id_type_panne=panne_data.id_type_panne,
        id_superviseur=superviseur.id_superviseur,
        priorite=priorite_calculée,
        gravite=panne_data.gravite,
        statut=StatutPanneEnum.EN_ATTENTE,
    )
    db.add(nouvelle_panne)
    db.commit()
    db.refresh(nouvelle_panne)

    # ── 4. Sélectionner le technicien optimal ─────────────────────────────────
    technicien, type_affectation = selectionner_technicien_optimal(
        db=db,
        id_machine=machine.id_machine,
    )

    technicien_info = None
    notification_result = None

    if technicien:
        # ── 5. Gérer l'affectation (Normale vs Exceptionnelle) ────────────────
        # ── Système LEONI : Chaque intervention INTER-GROUPE doit être validée par le chef d'équipe ──
        intervention = Intervention(
            id_panne=nouvelle_panne.id_panne,
            id_technicien=technicien.id_technicien,
            date_debut=datetime.utcnow(),
            type_affectation=type_affectation,
            statut=StatutInterventionEnum.EN_ATTENTE
        )
        db.add(intervention)
        db.flush()  # Pour obtenir l'ID de l'intervention

        # Vérifier si c'est inter-groupe
        # (type_affectation URGENTE vient de panne_util quand c'est un autre groupe)
        if type_affectation == TypeAffectationEnum.URGENTE:
            # Chercher le chef d'équipe du groupe du technicien
            chef = db.query(ChefEquipe).filter(
                ChefEquipe.id_groupe_supervise == technicien.id_groupe_principal
            ).first()

            if chef:
                autorisation = AutorisationExceptionnelle(
                    id_intervention=intervention.id_intervention,
                    id_chef_equipe=chef.id_chef,
                    statut=StatutAutorisationEnum.EN_ATTENTE
                )
                db.add(autorisation)
                db.commit()

                # Notifier le chef d'équipe
                notification_result = await notification_manager.notifier_chef_equipe_autorisation(
                    chef_id=chef.id_utilisateur,
                    panne_id=nouvelle_panne.id_panne,
                    technicien_nom=f"{technicien.utilisateur.prenom} {technicien.utilisateur.nom}",
                    fcm_token=None,
                    db_session=db
                )
            else:
                # Bloquer si pas de chef pour l'inter-groupe
                db.delete(intervention)
                db.commit()
                raise HTTPException(
                    status_code=400,
                    detail=f"Aucun chef d'équipe trouvé pour le groupe de {technicien.utilisateur.prenom} {technicien.utilisateur.nom}. Affectation inter-groupe impossible."
                )
        else:
            # Même groupe : affectation directe
            intervention.statut = StatutInterventionEnum.EN_ATTENTE
            nouvelle_panne.statut = StatutPanneEnum.EN_COURS
            technicien.statut = StatutTechnicienEnum.EN_INTERVENTION
            db.commit()

            # Notifier le technicien directement
            notification_result = await notification_manager.notifier_technicien_panne(
                technicien_id=technicien.id_technicien,
                technicien_nom=f"{technicien.utilisateur.prenom} {technicien.utilisateur.nom}",
                panne_id=nouvelle_panne.id_panne,
                machine_nom=machine.nom,
                machine_localisation=machine.localisation,
                type_panne=type_panne.nom_panne if type_panne else "Panne",
                gravite=nouvelle_panne.gravite.value if nouvelle_panne.gravite else "normale",
                priorite=nouvelle_panne.priorite,
                type_affectation="automatique",
                db_session=db
            )

        # Charger les infos pour la réponse
        technicien_info = {
            "id_technicien": technicien.id_technicien,
            "nom": technicien.utilisateur.nom,
            "prenom": technicien.utilisateur.prenom,
            "statut": technicien.statut.value,
            "type_affectation": type_affectation.value,
        }

    # ── 7. Réponse enrichie ───────────────────────────────────────────────────
    message = (
        f"Panne #{nouvelle_panne.id_panne} créée et en attente de validation par le chef d'équipe pour "
        f"{technicien_info['prenom']} {technicien_info['nom']}"
        if technicien_info
        else f"Panne #{nouvelle_panne.id_panne} créée. Aucun technicien disponible actuellement."
    )

    return PanneDetailResponse(
        id_panne=nouvelle_panne.id_panne,
        id_machine=nouvelle_panne.id_machine,
        id_type_panne=nouvelle_panne.id_type_panne,
        id_superviseur=nouvelle_panne.id_superviseur,
        priorite=nouvelle_panne.priorite,
        statut=nouvelle_panne.statut,
        date_declaration=nouvelle_panne.date_declaration,
        technicien_affecte=technicien_info,
        notification_envoyee=notification_result.get("websocket_envoye", False) if notification_result else False,
        message=message,
    )

@router_panne.post(
    "/machine/{id_machine}",
    response_model=PanneDetailResponse,
    summary="Déclarer une panne pour une machine spécifique",
)
async def creer_panne_machine(
    id_machine: int,
    panne_data_simple: dict,
    current_user=Depends(require_role(RoleEnum.SUPERVISEUR, RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """
    Similaire à /create mais avec id_machine dans le path.
    """
    from app.shema.panne import PanneCreate
    
    # Reconstruire PanneCreate avec validation
    try:
        full_data = PanneCreate(
            id_machine=id_machine,
            id_type_panne=panne_data_simple.get("id_type_panne"),
            id_superviseur=panne_data_simple.get("id_superviseur"),
            priorite=panne_data_simple.get("priorite", 3),
            gravite=panne_data_simple.get("gravite")
        )
    except Exception as e:
        raise HTTPException(status_code=422, detail=f"Données invalides : {str(e)}")
    
    return await creer_panne(panne_data=full_data, current_user=current_user, db=db)
