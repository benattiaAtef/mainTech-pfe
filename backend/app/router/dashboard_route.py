from datetime import datetime, date, time
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.core.database import get_db
from app.core.security import require_role
from app.models.enums import RoleEnum, StatutPanneEnum, StatutTechnicienEnum
from app.models.machine import Machine
from app.models.panne import Panne, TypePanne
from app.models.users import Technicien, Utilisateur
from app.models.intervention import Intervention

router_dashboard = APIRouter(prefix="/dashboard", tags=["Dashboard"])

@router_dashboard.get("/stats")
async def get_dashboard_stats(
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.MAGASINIER, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF - Obtenir les statistiques du tableau de bord"""
    
    # Initialiser les filtres
    machine_filter = []
    panne_filter = []
    tech_filter = []

    if current_user.role == RoleEnum.CHEF_EQUIPE:
        from app.models.users import ChefEquipe
        from app.models.machine import GroupeMachine
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            # Filtre pour les machines (via GroupeMachine)
            machine_filter = [Machine.id_groupe_machine.in_(
                db.query(GroupeMachine.id_groupe_machine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
            )]
            # Filtre pour les pannes (via Machine)
            panne_filter = [Panne.id_machine.in_(
                db.query(Machine.id_machine).join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
            )]
            # Filtre pour les techniciens
            tech_filter = [Technicien.id_groupe_principal == chef.id_groupe_supervise]
        else:
            # Si pas de groupe supervisé, on renvoie des zéros
            return {
                "machines": {"total": 0, "operationnelles": 0, "en_panne": 0},
                "pannes": {"total_actives": 0, "en_attente": 0, "en_cours": 0},
                "techniciens": {"total": 0, "disponibles": 0, "en_intervention": 0}
            }

    # 1. Stats Machines
    total_machines = db.query(Machine).filter(*machine_filter).count()
    
    # Machines en panne
    machines_en_panne = db.query(Machine.id_machine).join(Panne).filter(
        Panne.statut.in_([StatutPanneEnum.EN_ATTENTE, StatutPanneEnum.EN_COURS, StatutPanneEnum.A_VALIDER]),
        *machine_filter
    ).distinct().count()
    
    machines_operationnelles = total_machines - machines_en_panne
    
    # 2. Stats Pannes
    total_pannes_actives = db.query(Panne).filter(
        Panne.statut.in_([StatutPanneEnum.EN_ATTENTE, StatutPanneEnum.EN_COURS, StatutPanneEnum.A_VALIDER]),
        *panne_filter
    ).count()
    
    pannes_en_attente = db.query(Panne).filter(Panne.statut == StatutPanneEnum.EN_ATTENTE, *panne_filter).count()
    pannes_en_cours = db.query(Panne).filter(Panne.statut == StatutPanneEnum.EN_COURS, *panne_filter).count()
    
    # 3. Stats Techniciens
    total_techniciens = db.query(Technicien).filter(*tech_filter).count()
    tech_disponibles = db.query(Technicien).filter(Technicien.statut == StatutTechnicienEnum.DISPONIBLE, *tech_filter).count()
    tech_en_intervention = db.query(Technicien).filter(Technicien.statut == StatutTechnicienEnum.EN_INTERVENTION, *tech_filter).count()
    
    # 4. Stats Interventions (Auj.)
    today_start = datetime.combine(date.today(), time.min)
    # Filtre par machine si Chef Equipe
    intervention_filter = []
    if current_user.role == RoleEnum.CHEF_EQUIPE and machine_filter:
         intervention_filter = [Intervention.id_panne.in_(
             db.query(Panne.id_panne).filter(*panne_filter)
         )]
    
    total_interventions_today = db.query(Intervention).filter(
        Intervention.date_debut >= today_start,
        *intervention_filter
    ).count()

    # 5. Utilisateurs Totaux
    total_users = db.query(Utilisateur).count()

    return {
        "machines": {
            "total": total_machines,
            "operationnelles": machines_operationnelles,
            "en_panne": machines_en_panne
        },
        "pannes": {
            "total_actives": total_pannes_actives,
            "en_attente": pannes_en_attente,
            "en_cours": pannes_en_cours
        },
        "techniciens": {
            "total": total_techniciens,
            "disponibles": tech_disponibles,
            "en_intervention": tech_en_intervention
        },
        "interventions": {
            "today": total_interventions_today
        },
        "users": {
            "total": total_users
        }
    }

@router_dashboard.get("/recent-activities")
async def get_recent_activities(
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.MAGASINIER, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF - Obtenir le flux des activités récentes"""
    
    # 1. Dernières Pannes
    latest_pannes = db.query(Panne).join(Machine).join(TypePanne).order_by(Panne.date_declaration.desc()).limit(5).all()
    
    # 2. Dernières Interventions
    latest_interventions = db.query(Intervention).join(Technicien).join(Utilisateur).order_by(Intervention.date_debut.desc()).limit(5).all()
    
    # 3. Derniers Utilisateurs
    latest_users = db.query(Utilisateur).order_by(Utilisateur.id_utilisateur.desc()).limit(3).all()

    activities = []
    
    for p in latest_pannes:
        activities.append({
            "text": f"Nouvelle panne : {p.type_panne.nom_panne} sur {p.machine.nom}",
            "date": p.date_declaration.isoformat() if p.date_declaration else None,
            "type": "panne",
            "color": "errorRed"
        })
        
    for i in latest_interventions:
        status_text = "terminée" if i.statut == "TERMINEE" else "démarrée"
        activities.append({
            "text": f"Intervention #{i.id_intervention} {status_text} par {i.technicien.utilisateur.nom}",
            "date": (i.date_fin or i.date_debut).isoformat() if (i.date_fin or i.date_debut) else None,
            "type": "intervention",
            "color": "successGreen" if i.statut == "TERMINEE" else "primaryBlue"
        })
        
    for u in latest_users:
        activities.append({
            "text": f"Nouvel utilisateur : {u.prenom} {u.nom} ({u.role})",
            "date": None,
            "type": "user",
            "color": "warningOrange"
        })

    # Trier par date (ceux qui ont une date)
    activities.sort(key=lambda x: x['date'] if x['date'] else "", reverse=True)
    
    return activities[:10]
