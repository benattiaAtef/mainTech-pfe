from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.security import require_role
from app.models.competence import GroupeTechnicien
from app.models.enums import RoleEnum
from app.models.machine import GroupeMachine
from app.models.users import Technicien, ChefEquipe, Utilisateur
from sqlalchemy.orm import joinedload
from app.shema.competence_schema import GroupeTechnicienCreate, GroupeMachineCreate
from app.router.technicien_route import get_technician_stats

router_groupes = APIRouter(prefix="/groupes", tags=["Groupes"])


@router_groupes.post("/techniciens")
async def create_groupe_tech(
    groupe_data: GroupeTechnicienCreate,
    admin = Depends(require_role(RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN - Créer groupe techniciens"""
    nouveau_groupe = GroupeTechnicien(**groupe_data.model_dump())
    db.add(nouveau_groupe)
    db.commit()
    db.refresh(nouveau_groupe)
    return nouveau_groupe


@router_groupes.post("/machines")
async def create_groupe_machine(
    groupe_data: GroupeMachineCreate,
    admin = Depends(require_role(RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN - Créer groupe machines"""
    nouveau_groupe = GroupeMachine(**groupe_data.model_dump())
    db.add(nouveau_groupe)
    db.commit()
    db.refresh(nouveau_groupe)
    return nouveau_groupe


@router_groupes.get("/techniciens")
async def list_groupes_tech(
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF_EQUIPE - Lister les groupes de techniciens"""
    groupes = db.query(GroupeTechnicien).all()
    return [
        {"id_groupe_tech": g.id_groupe_tech, "nom_groupe": g.nom_groupe, "nombre_min_dispo": g.nombre_min_dispo}
        for g in groupes
    ]


@router_groupes.get("/machines")
async def list_groupes_machines(
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF_EQUIPE - Lister les groupes de machines"""
    groupes = db.query(GroupeMachine).all()
    return [
        {"id_groupe_machine": g.id_groupe_machine, "nom_groupe": g.nom_groupe, "niveau_priorite": g.niveau_priorite}
        for g in groupes
    ]
@router_groupes.get("/{id_groupe}/membres")
async def list_membres_groupe(
    id_groupe: int,
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db)
):
    """Lister tous les membres (techniciens + chef) d'un groupe avec leur statut de présence"""
    # 1. Récupérer les techniciens
    techniciens = db.query(Technicien)\
        .options(joinedload(Technicien.utilisateur))\
        .filter(Technicien.id_groupe_principal == id_groupe).all()
    
    # 2. Récupérer le chef
    chef = db.query(ChefEquipe)\
        .options(joinedload(ChefEquipe.utilisateur))\
        .filter(ChefEquipe.id_groupe_supervise == id_groupe).first()
    
    membres = []
    
    # Ajouter le chef si il existe
    if chef and chef.utilisateur:
        membres.append({
            "id_utilisateur": chef.utilisateur.id_utilisateur,
            "nom": chef.utilisateur.nom,
            "prenom": chef.utilisateur.prenom,
            "role": "Chef d'équipe",
            "is_chef": True,
            "statut_presence": chef.utilisateur.statut_presence.value if chef.utilisateur.statut_presence else "hors_travail"
        })
    
    # Ajouter les techniciens
    for tech in techniciens:
        if tech.utilisateur:
            interv_count, total_min = get_technician_stats(db, tech)
            membres.append({
                "id_technicien": tech.id_technicien,
                "id_utilisateur": tech.utilisateur.id_utilisateur,
                "nom": tech.utilisateur.nom,
                "prenom": tech.utilisateur.prenom,
                "role": "Technicien",
                "is_chef": False,
                "statut": tech.statut.value if tech.statut else "disponible",
                "statut_presence": tech.utilisateur.statut_presence.value if tech.utilisateur.statut_presence else "hors_travail",
                "interventions_count_today": interv_count,
                "total_time_today_minutes": total_min
            })
            
    return membres
