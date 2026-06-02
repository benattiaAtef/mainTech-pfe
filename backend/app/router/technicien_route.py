from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.models.users import Technicien, Utilisateur  # tes modèles SQLAlchemy
from app.shema.technicien import StatutUpdate, TechnCreate, TechnicienUpdate, TechnicienResponse  # tes Pydantic schemas
from app.core.database import get_db
from app.core.security import get_current_user, get_password_hash, require_role
from app.models.enums import RoleEnum, StatutTechnicienEnum, StatutPresenceEnum
from app.models.intervention import Intervention
from app.models.panne import Panne
from app.shema.intervention import InterventionDetailResponse
from app.utils.panne_util import assigner_panne_en_attente_si_possible

router_techniciens = APIRouter(prefix="/techniciens", tags=["Techniciens"])

def get_technician_stats(db: Session, tech: Technicien):
    """Calculates today's stats for a technician (only time spent today)."""
    import datetime
    from sqlalchemy import or_
    
    now = datetime.datetime.utcnow()
    # today_start is the start of the current day in UTC
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    
    # Fetch all interventions that could overlap with today
    interventions = db.query(Intervention).filter(
        Intervention.id_technicien == tech.id_technicien,
        Intervention.date_debut <= now,
        or_(
            Intervention.date_fin == None,
            Intervention.date_fin >= today_start
        )
    ).all()
    
    count_today = 0
    total_minutes = 0.0
    
    for i in interventions:
        # Count if it started today
        if i.date_debut >= today_start:
            count_today += 1
            
        # Time calculation only for today's portion
        start_work = i.date_scan_qr if i.date_scan_qr else i.date_debut
        end_work = i.date_fin if i.date_fin else now
        
        # Intersection interval with [today_start, now]
        start_intersect = max(start_work, today_start)
        end_intersect = min(end_work, now)
        
        if start_intersect < end_intersect:
            total_minutes += (end_intersect - start_intersect).total_seconds() / 60
            
    return count_today, int(total_minutes)

@router_techniciens.post("/create", response_model=TechnicienResponse)
async def create_technicien(
    technicien_data: TechnCreate,
    user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    # 1. Vérifier si l'email existe déjà chez n'importe quel utilisateur
    existing_user = db.query(Utilisateur).filter(Utilisateur.email == technicien_data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé par un autre utilisateur (technicien, chef ou superviseur).")

    # 2. Vérifier si le matricule est déjà utilisé
    if technicien_data.matricule:
        existing_matricule = db.query(Technicien).filter(Technicien.matricule == technicien_data.matricule).first()
        if existing_matricule:
            raise HTTPException(status_code=400, detail="Ce matricule est déjà attribué à un autre technicien.")

    # 3. Vérification d'accès pour CHEF_EQUIPE
    if user.role == RoleEnum.CHEF_EQUIPE:
        from app.models.users import ChefEquipe
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or technicien_data.id_groupe_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Vous ne pouvez créer des techniciens que pour votre groupe supervisé")

    # Créer l'utilisateur
    new_user = Utilisateur(
        nom=technicien_data.nom,
        prenom=technicien_data.prenom,
        email=technicien_data.email,
        mot_de_passe=get_password_hash(technicien_data.mot_de_passe),
        role=RoleEnum.TECHNICIEN.value,
        statut_presence=StatutPresenceEnum.EN_TRAVAIL.value
    )
    db.add(new_user)
    print(f"DEBUG: Creating Technicien - Role: {new_user.role}, Statut: {new_user.statut_presence}")
    db.commit()
    db.refresh(new_user)

    # Créer le technicien lié
    new_tech = Technicien(
        id_utilisateur=new_user.id_utilisateur,
        id_groupe_principal=technicien_data.id_groupe_principal,
        statut=technicien_data.statut,
        position_lat=technicien_data.position_lat,
        position_lng=technicien_data.position_lng
    )
    db.add(new_tech)
    db.commit()
    db.refresh(new_tech)

    # Créer les compétences (groupes de renfort)
    from app.models.competence import CompetenceTechnicien
    for machine_group_id in technicien_data.competences_ids:
        comp = CompetenceTechnicien(
            id_technicien=new_tech.id_technicien,
            id_groupe_machine=machine_group_id
        )
        db.add(comp)
    
    if technicien_data.competences_ids:
        db.commit()

    technicien = db.query(Technicien)\
    .options(joinedload(Technicien.utilisateur))\
    .options(joinedload(Technicien.competences))\
    .filter(Technicien.id_technicien == new_tech.id_technicien)\
    .first()

    return technicien

@router_techniciens.get("/me", response_model=TechnicienResponse)
async def get_my_technicien_profile(
    current_user = Depends(require_role(RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db)
):
    """✅ TECHNICIEN - Récupérer son propre profil"""
    tech = db.query(Technicien)\
        .options(joinedload(Technicien.utilisateur))\
        .options(joinedload(Technicien.competences))\
        .filter(Technicien.id_utilisateur == current_user.id_utilisateur)\
        .first()
    if not tech:
        raise HTTPException(status_code=404, detail="Profil technicien introuvable")
    
    # Add stats
    count, minutes = get_technician_stats(db, tech)
    
    # We convert to dict to add extra fields not in DB model but in Schema
    tech_dict = tech.__dict__.copy()
    if "_sa_instance_state" in tech_dict:
        del tech_dict["_sa_instance_state"]
        
    tech_dict['interventions_count_today'] = count
    tech_dict['total_time_today_minutes'] = minutes
    
    return tech_dict



@router_techniciens.get("/", response_model=list[TechnicienResponse])
async def list_techniciens(
    id_machine: int = None,
    id_groupe: int = None,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN (tous), CHEF (groupe), TECH (groupe) - Liste des techniciens"""
    from app.models.users import ChefEquipe, Technicien as TechModel
    
    query = db.query(TechModel)\
        .options(joinedload(TechModel.utilisateur))\
        .options(joinedload(TechModel.competences))
    
    # Isolation des données
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise:
            return []
        query = query.filter(TechModel.id_groupe_principal == chef.id_groupe_supervise)
            
    elif current_user.role == RoleEnum.TECHNICIEN:
        # Un technicien peut voir les membres de son propre groupe principal
        tech = db.query(TechModel).filter(TechModel.id_utilisateur == current_user.id_utilisateur).first()
        if not tech or not tech.id_groupe_principal:
            return []
        query = query.filter(TechModel.id_groupe_principal == tech.id_groupe_principal)

    elif current_user.role in [RoleEnum.ADMINISTRATEUR, RoleEnum.SUPERVISEUR]:
        if id_groupe:
            query = query.filter(TechModel.id_groupe_principal == id_groupe)
        if id_machine:
            from app.models.machine import Machine
            from app.models.competence import CompetenceTechnicien
            machine = db.query(Machine).filter(Machine.id_machine == id_machine).first()
            if machine:
                query = query.filter(TechModel.id_technicien.in_(
                    db.query(CompetenceTechnicien.id_technicien).filter(
                        CompetenceTechnicien.id_groupe_machine == machine.id_groupe_machine
                    )
                ))
    else:
        raise HTTPException(status_code=403, detail="Non autorisé")
        
    techniciens = query.all()
    
    result = []
    for tech in techniciens:
        count, minutes = get_technician_stats(db, tech)
        
        tech_dict = tech.__dict__.copy()
        if "_sa_instance_state" in tech_dict:
            del tech_dict["_sa_instance_state"]
            
        tech_dict['interventions_count_today'] = count
        tech_dict['total_time_today_minutes'] = minutes
        result.append(tech_dict)
        
    return result


@router_techniciens.put("/{technicien_id}/statut")
async def update_statut(
    technicien_id: int,
    statut_update: StatutUpdate,  # Body JSON
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    tech = db.query(Technicien).filter(Technicien.id_technicien == technicien_id).first()
    if not tech:
        raise HTTPException(status_code=404, detail="Technicien introuvable")
    
    # Vérification des permissions
    if tech.id_utilisateur != current_user.id_utilisateur:
        if current_user.role not in [RoleEnum.SUPERVISEUR, RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE]:
            raise HTTPException(status_code=403, detail="Non autorisé")
    
    from datetime import datetime
    ancien_statut = tech.statut
    tech.statut = statut_update.statut.value
    tech.date_dernier_statut = datetime.utcnow()
    db.commit()

    # ✅ Si le technicien vient de devenir DISPONIBLE, chercher une panne en attente
    if (statut_update.statut == StatutTechnicienEnum.DISPONIBLE
            and ancien_statut != StatutTechnicienEnum.DISPONIBLE):
        await assigner_panne_en_attente_si_possible(db, technicien_id)

    return {"message": "Statut mis à jour"}



@router_techniciens.get("/{technicien_id}/interventions", response_model=list[InterventionDetailResponse])
async def get_mes_interventions(
    technicien_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """✅ TECHNICIEN - Mes interventions"""
    
    tech = db.query(Technicien).filter(Technicien.id_technicien == technicien_id).first()
    if not tech:
        raise HTTPException(status_code=404, detail="Technicien introuvable")
    
    # Vérifier que c'est son profil ou admin/superviseur
    if tech.id_utilisateur != current_user.id_utilisateur:
        if current_user.role not in [RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR]:
            raise HTTPException(status_code=403, detail="Non autorisé")
    
    interventions = db.query(Intervention).options(
        joinedload(Intervention.panne).joinedload(Panne.machine)
    ).filter(
        Intervention.id_technicien == technicien_id
    ).all()
    return interventions


@router_techniciens.put("/{technicien_id}", response_model=TechnicienResponse)
async def update_technicien(
    technicien_id: int,
    tech_data: TechnicienUpdate,
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF_EQUIPE - Modifier technicien (avec vérification)"""
    from app.models.users import ChefEquipe
    
    tech = db.query(Technicien).filter(Technicien.id_technicien == technicien_id).first()
    if not tech:
        raise HTTPException(status_code=404, detail="Technicien introuvable")
    
    # Vérification d'accès pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or tech.id_groupe_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Non autorisé à modifier ce technicien")

    # Mettre à jour les champs fournis
    update_data = tech_data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(tech, key, value)
    
    db.commit()
    db.refresh(tech)
    
    # Recharger avec l'utilisateur pour la réponse
    tech = db.query(Technicien)\
        .options(joinedload(Technicien.utilisateur))\
        .options(joinedload(Technicien.competences))\
        .filter(Technicien.id_technicien == technicien_id)\
        .first()
        
    return tech


@router_techniciens.delete("/{technicien_id}")
async def delete_technicien(
    technicien_id: int,
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF_EQUIPE - Supprimer technicien (avec vérification)"""
    from app.models.users import ChefEquipe
    
    tech = db.query(Technicien).filter(Technicien.id_technicien == technicien_id).first()
    if not tech:
        raise HTTPException(status_code=404, detail="Technicien introuvable")
    
    # Vérification d'accès pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or tech.id_groupe_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Non autorisé à supprimer ce technicien")

    # Supprimer l'utilisateur lié
    db.delete(tech.utilisateur)
    db.commit()
    return {"message": "Technicien supprimé"}
