from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.models.enums import RoleEnum
from app.models.machine import Machine, GroupeMachine
from app.shema.machine import MachineCreate, MachineUpdate, MachineResponse, Qrcode
from app.core.security import get_current_user, require_role
from app.models.enums import RoleEnum

router_machines = APIRouter(prefix="/machines", tags=["Machines"])

@router_machines.post("/create", response_model=MachineResponse)
async def create_machine(
    machine_data: MachineCreate,
    user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, SUPERVISEUR - Créer une machine"""
    
    # Vérifier que le groupe existe
    groupe = db.query(GroupeMachine).filter(GroupeMachine.id_groupe_machine == machine_data.id_groupe_machine).first()
    if not groupe:
        raise HTTPException(status_code=404, detail="Groupe machine introuvable")

    # Vérification d'accès pour CHEF_EQUIPE
    if user.role == RoleEnum.CHEF_EQUIPE:
        from app.models.users import ChefEquipe
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or groupe.id_groupe_tech_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Vous ne pouvez créer des machines que pour votre groupe supervisé")

    # Créer la machine
    machine = Machine(
        nom=machine_data.nom,
        id_groupe_machine=machine_data.id_groupe_machine,
        qr_code=machine_data.qr_code,
        localisation=machine_data.localisation,
        num_serie=machine_data.num_serie,
        date_installation=machine_data.date_installation,
        fonction=machine_data.fonction
    )
    db.add(machine)
    db.commit()
    db.refresh(machine)
    
    # Préparer la réponse
    response = MachineResponse(
        id_machine=machine.id_machine,
        nom=machine.nom,
        qr_code=machine.qr_code,
        localisation=machine.localisation,
        id_groupe_machine=machine.id_groupe_machine,
        groupe_nom=groupe.nom_groupe,
        num_serie=machine.num_serie,
        date_installation=machine.date_installation,
        fonction=machine.fonction,
        statut="Opérationnel",
        id_groupe_tech_principal=groupe.id_groupe_tech_principal
    )
    
    return response



@router_machines.get("/", response_model=list[MachineResponse])
async def list_machines(
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """✅ TOUS - Liste machines (filtrée pour CHEF_EQUIPE)"""
    from app.models.panne import Panne
    from app.models.enums import StatutPanneEnum, RoleEnum
    from app.models.users import ChefEquipe
    
    query = db.query(Machine)
    
    # Isolation des données pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            query = query.join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == chef.id_groupe_supervise)
        else:
            return []
            
    # Isolation des données pour TECHNICIEN
    elif current_user.role == RoleEnum.TECHNICIEN:
        from app.models.users import Technicien
        tech = db.query(Technicien).filter(Technicien.id_utilisateur == current_user.id_utilisateur).first()
        if tech and tech.id_groupe_principal:
            query = query.join(GroupeMachine).filter(GroupeMachine.id_groupe_tech_principal == tech.id_groupe_principal)
        else:
            return []
    
    machines = query.all()
    result = []
    
    for m in machines:
        # Vérifier s'il y a une panne active (EN_ATTENTE ou EN_COURS uniquement)
        active_pannes = db.query(Panne).filter(
            Panne.id_machine == m.id_machine,
            Panne.statut.in_([StatutPanneEnum.EN_ATTENTE, StatutPanneEnum.EN_COURS])
        ).all()
        
        statut = "Opérationnel"
        if active_pannes:
            statut = "Non opérationnel"
        
        # Mapper vers MachineResponse
        machine_res = MachineResponse.from_orm(m)
        machine_res.statut = statut
        if m.groupe_machine:
            machine_res.groupe_nom = m.groupe_machine.nom_groupe
            machine_res.id_groupe_tech_principal = m.groupe_machine.id_groupe_tech_principal
            
        result.append(machine_res)
        
    return result


@router_machines.post("/qrcode", response_model=MachineResponse)
async def scan_qrcode(
    qr_code: Qrcode,
    user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.TECHNICIEN, RoleEnum.SUPERVISEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 TOUS - Scanner QR Code (Case-insensitive & Robust Substring)"""
    scanned_value = qr_code.qrcode.strip()
    print(f"\n[DEBUG QR SCAN] Valeur reçue: '{scanned_value}'")
    
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
                    
    if not machine:
        import logging
        logger = logging.getLogger(__name__)
        logger.warning(f"Scan QR échoué : '{scanned_value}' non trouvé dans la base.")
        print(f"[DEBUG QR SCAN] Aucun match trouvé pour '{scanned_value}'")
        raise HTTPException(status_code=404, detail=f"Machine introuvable pour le code : {scanned_value}")
    
    # Mapper vers MachineResponse avec statut
    from app.models.panne import Panne
    from app.models.enums import StatutPanneEnum
    
    active_pannes = db.query(Panne).filter(
        Panne.id_machine == machine.id_machine,
        Panne.statut.in_([StatutPanneEnum.EN_ATTENTE, StatutPanneEnum.EN_COURS])
    ).all()
    
    statut = "Opérationnel"
    if active_pannes:
        statut = "En panne"
    
    response = MachineResponse.from_orm(machine)
    response.statut = statut
    if machine.groupe_machine:
        response.groupe_nom = machine.groupe_machine.nom_groupe
        response.id_groupe_tech_principal = machine.groupe_machine.id_groupe_tech_principal
        
    return response


@router_machines.get("/{machine_id}", response_model=MachineResponse)
async def get_machine(
    machine_id: int,
    current_user = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """✅ TOUS - Détails machine (avec vérification d'accès pour CHEF_EQUIPE)"""
    from app.models.panne import Panne
    from app.models.enums import StatutPanneEnum, RoleEnum
    from app.models.users import ChefEquipe
    
    machine = db.query(Machine).filter(Machine.id_machine == machine_id).first()
    if not machine:
        raise HTTPException(status_code=404, detail="Machine introuvable")
    
    # Vérification d'accès pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or machine.groupe_machine.id_groupe_tech_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Accès refusé à cette machine")

    # Vérifier s'il y a une panne active
    active_pannes = db.query(Panne).filter(
        Panne.id_machine == machine.id_machine,
        Panne.statut.in_([StatutPanneEnum.EN_ATTENTE, StatutPanneEnum.EN_COURS])
    ).all()
    
    statut = "Opérationnel"
    if active_pannes:
        statut = "En panne"
    
    response = MachineResponse.from_orm(machine)
    response.statut = statut
    if machine.groupe_machine:
        response.groupe_nom = machine.groupe_machine.nom_groupe
        response.id_groupe_tech_principal = machine.groupe_machine.id_groupe_tech_principal
        
    return response


@router_machines.put("/{machine_id}", response_model=MachineResponse)
async def update_machine(
    machine_id: int,
    machine_data: MachineUpdate,
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF_EQUIPE - Modifier machine (avec vérification d'accès)"""
    from app.models.users import ChefEquipe
    
    machine = db.query(Machine).filter(Machine.id_machine == machine_id).first()
    if not machine:
        raise HTTPException(status_code=404, detail="Machine introuvable")
    
    # Vérification d'accès pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or machine.groupe_machine.id_groupe_tech_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Non autorisé à modifier cette machine")

    # Mettre à jour les champs fournis
    update_data = machine_data.dict(exclude_unset=True)
    for key, value in update_data.items():
        setattr(machine, key, value)
    
    db.commit()
    db.refresh(machine)
    
    # Recharger les infos (groupe, statut) pour la réponse
    from app.models.panne import Panne
    from app.models.enums import StatutPanneEnum
    
    active_pannes = db.query(Panne).filter(
        Panne.id_machine == machine.id_machine,
        Panne.statut.in_([StatutPanneEnum.EN_ATTENTE, StatutPanneEnum.EN_COURS])
    ).all()
    
    statut = "Opérationnel"
    if active_pannes:
        statut = "En panne"
    
    response = MachineResponse.from_orm(machine)
    response.statut = statut
    if machine.groupe_machine:
        response.groupe_nom = machine.groupe_machine.nom_groupe
        response.id_groupe_tech_principal = machine.groupe_machine.id_groupe_tech_principal
        
    return response


@router_machines.delete("/{machine_id}")
async def delete_machine(
    machine_id: int,
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF_EQUIPE - Supprimer machine (avec vérification)"""
    from app.models.users import ChefEquipe
    
    machine = db.query(Machine).filter(Machine.id_machine == machine_id).first()
    if not machine:
        raise HTTPException(status_code=404, detail="Machine introuvable")
    
    # Vérification d'accès pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if not chef or not chef.id_groupe_supervise or machine.groupe_machine.id_groupe_tech_principal != chef.id_groupe_supervise:
            raise HTTPException(status_code=403, detail="Non autorisé à supprimer cette machine")

    db.delete(machine)
    db.commit()
    return {"message": "Machine supprimée"}