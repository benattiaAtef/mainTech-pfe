
from fastapi import APIRouter, Depends, HTTPException, HTTPException,status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import get_current_user,get_current_active_user, require_role
from app.models.enums import RoleEnum, StatutPresenceEnum, StatutTechnicienEnum
from app.models.users import Utilisateur
from app.shema.user import UtilisateurResponse, FCMTokenUpdate
from app.utils.panne_util import assigner_panne_en_attente_si_possible

router_users = APIRouter(prefix="/users", tags=["Utilisateurs"])



@router_users.get("/me",response_model=UtilisateurResponse, status_code=status.HTTP_200_OK)
async def get_my_profile(current_user = Depends(get_current_user)):
    """✅ TOUS - Mon profil"""
    return {
        "id_utilisateur": current_user.id_utilisateur,
        "nom": current_user.nom,
        "prenom": current_user.prenom,
        "email": current_user.email,
        "role": current_user.role.value,
        "statut_presence": current_user.statut_presence.value
    }

@router_users.get("/me/chef")
async def get_my_chef_profile(
    current_user = Depends(require_role(RoleEnum.CHEF_EQUIPE, RoleEnum.TECHNICIEN, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db)
):
    """🔒 CHEF/TECH/SUPERVISEUR - Mes détails de supervision"""
    from app.models.users import ChefEquipe, Technicien, Superviseur
    
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef:
            raise HTTPException(status_code=404, detail="Profil chef introuvable")
        return {
            "id_chef": chef.id_chef,
            "id_groupe_supervise": chef.id_groupe_supervise,
            "nom_groupe": chef.groupe_supervise.nom_groupe if chef.groupe_supervise else "Inconnu",
            "utilisateur": {
                "nom": current_user.nom,
                "prenom": current_user.prenom,
                "email": current_user.email
            }
        }
    
    elif current_user.role == RoleEnum.TECHNICIEN:
        tech = db.query(Technicien).filter(Technicien.id_utilisateur == current_user.id_utilisateur).first()
        if not tech:
            raise HTTPException(status_code=404, detail="Profil technicien introuvable")
        return {
            "id_chef": None,
            "id_groupe_supervise": tech.id_groupe_principal,
            "nom_groupe": tech.groupe_principal.nom_groupe if tech.groupe_principal else "Inconnu",
            "utilisateur": {
                "nom": current_user.nom,
                "prenom": current_user.prenom,
                "email": current_user.email
            }
        }
        
    elif current_user.role == RoleEnum.SUPERVISEUR:
        sup = db.query(Superviseur).filter(Superviseur.id_utilisateur == current_user.id_utilisateur).first()
        return {
            "id_chef": None,
            "id_groupe_supervise": None,
            "nom_groupe": sup.zone_responsabilite if sup else "Zone indéfinie",
            "utilisateur": {
                "nom": current_user.nom,
                "prenom": current_user.prenom,
                "email": current_user.email
            }
        }


@router_users.put("/me/presence")
async def update_my_presence(
    statut: StatutPresenceEnum,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """✅ TOUS - Changer mon statut de présence (En travail / Hors travail)"""
    current_user.statut_presence = statut
    
    # Si c'est un technicien et qu'il se met En Travail
    if current_user.role == RoleEnum.TECHNICIEN and statut == StatutPresenceEnum.EN_TRAVAIL:
        if current_user.technicien:
            from app.models.intervention import Intervention
            from app.models.enums import StatutInterventionEnum
            # On ne le remet DISPONIBLE que s'il n'a pas déjà une intervention en cours/acceptée
            active_inv = db.query(Intervention).filter(
                Intervention.id_technicien == current_user.technicien.id_technicien,
                Intervention.statut.in_([StatutInterventionEnum.ACCEPTEE, StatutInterventionEnum.EN_COURS])
            ).first()
            
            if not active_inv:
                current_user.technicien.statut = StatutTechnicienEnum.DISPONIBLE
                db.commit()
                await assigner_panne_en_attente_si_possible(db, current_user.technicien.id_technicien)
            else:
                db.commit() # Just save presence
            
    # Si c'est un technicien et qu'il se met Hors Travail
    elif current_user.role == RoleEnum.TECHNICIEN and statut == StatutPresenceEnum.HORS_TRAVAIL:
        if current_user.technicien:
            current_user.technicien.statut = StatutTechnicienEnum.INDISPONIBLE
            db.commit()
    else:
        db.commit()
    return {"message": "Statut de présence mis à jour", "statut_presence": statut.value}
    
@router_users.put("/me/fcm")
async def update_my_fcm_token(
    data: FCMTokenUpdate,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """✅ TOUS - Enregistrer le token FCM pour les notifications push"""
    current_user.fcm_token = data.fcm_token
    db.commit()
    return {"message": "Token FCM mis à jour"}



@router_users.get("/")
async def list_users(
    admin = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN - Liste tous les utilisateurs"""
    users = db.query(Utilisateur).all()
    return users


@router_users.get("/{user_id}")
async def get_user(
    user_id: int,
    admin = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN - Détails utilisateur"""
    user = db.query(Utilisateur).filter(Utilisateur.id_utilisateur == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    return user


@router_users.delete("/{user_id}")
async def delete_user(
    user_id: int,
    admin = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN - Supprimer utilisateur"""
    user = db.query(Utilisateur).filter(Utilisateur.id_utilisateur == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    db.delete(user)
    db.commit()
    return {"message": "Utilisateur supprimé"}