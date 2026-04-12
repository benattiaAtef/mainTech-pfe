



from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.core.database import get_db
from app.core.security import require_role
from app.models.enums import RoleEnum, StatutPanneEnum, StatutTechnicienEnum, StatutInterventionEnum, TypeAffectationEnum, StatutAutorisationEnum
from app.models.intervention import Intervention, RapportPanne
from app.models.panne import Panne
from app.models.users import Technicien
from app.models.autorisation import AutorisationExceptionnelle
from app.shema.intervention import (
    InterventionCreate,
    InterventionUpdate,
    InterventionResponse,
    InterventionDetailResponse,
    RapportPanneCreate,
    RapportPanneResponse,
    TerminerInterventionResponse
)
from app.utils.panne_util import assigner_panne_en_attente_si_possible, selectionner_technicien_optimal
from app.utils import stats_util




router_interventions = APIRouter(prefix="/interventions", tags=["Interventions"])

@router_interventions.get(
    "/",
    response_model=list[InterventionDetailResponse],
    summary="Lister toutes les interventions",
)
async def lister_interventions(
    skip: int = 0,
    limit: int = 100,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR
    )),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF, SUPERVISEUR - Liste interventions (filtrée pour CHEF)"""
    from app.models.users import ChefEquipe
    from app.models.machine import GroupeMachine, Machine
    from sqlalchemy import or_

    query = db.query(Intervention).options(
        joinedload(Intervention.technicien).joinedload(Technicien.utilisateur),
        joinedload(Intervention.panne).joinedload(Panne.machine)
    )

    # Isolation pour CHEF_EQUIPE : voit les interventions sur SES machines OU par SES techniciens
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            # On utilise .has() qui génère un EXISTS, plus sûr que les joins manuels ici
            query = query.filter(or_(
                Intervention.panne.has(Panne.machine.has(Machine.id_groupe_machine == chef.id_groupe_supervise)),
                Intervention.technicien.has(Technicien.id_groupe_principal == chef.id_groupe_supervise)
            ))
        else:
            return []

    pannes_en_attente = db.query(Panne).filter(
        Panne.statut == StatutPanneEnum.EN_ATTENTE
    ).options(joinedload(Panne.machine).joinedload(Machine.groupe_machine)).all()

    # Si CHEF_EQUIPE, filtrer les pannes aussi
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef and chef.id_groupe_supervise:
            pannes_en_attente = [p for p in pannes_en_attente if p.machine.groupe_machine.id_groupe_tech_principal == chef.id_groupe_supervise]
        else:
            pannes_en_attente = []

    # Mapper les pannes sans intervention en objets simulant une intervention
    virtual_interventions = []
    # On récupère les IDs des pannes qui ont déjà une intervention
    ids_pannes_avec_interv = {i.id_panne for i in query.all()}
    
    for p in pannes_en_attente:
        if p.id_panne not in ids_pannes_avec_interv:
            # Créer un objet factice (dict) que Pydantic pourra valider si from_orm est bien géré 
            # ou si on le transforme en objet
            virtual_interventions.append({
                "id_intervention": -p.id_panne, # ID négatif unique basé sur id_panne
                "id_panne": p.id_panne,
                "id_technicien": 0,
                "date_debut": p.date_declaration,
                "statut": StatutInterventionEnum.EN_ATTENTE,
                "type_affectation": TypeAffectationEnum.AUTOMATIQUE,
                "panne": p,
                "technicien": None
            })

    interventions_reelles = query.offset(skip).limit(limit).all()
    
    # Combiner et retourner (on peut trier par date)
    result = list(interventions_reelles) + virtual_interventions
    
    def get_sort_key(x):
        dt = x.date_debut if hasattr(x, 'date_debut') else x['date_debut']
        if dt and dt.tzinfo:
            return dt.replace(tzinfo=None)
        return dt

    result.sort(key=get_sort_key, reverse=True)

    return result


from sqlalchemy.orm import joinedload

@router_interventions.get(
    "/technicien/{id_technicien}",
    response_model=list[InterventionDetailResponse],
    summary="Interventions d'un technicien",
)
async def interventions_par_technicien(
    id_technicien: int,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.TECHNICIEN
    )),
    db: Session = Depends(get_db),
):
    technicien = db.query(Technicien).filter(
        Technicien.id_technicien == id_technicien
    ).first()

    if not technicien:
        raise HTTPException(status_code=404, detail="Technicien introuvable")

    if current_user.role == RoleEnum.TECHNICIEN:
        if technicien.id_utilisateur != current_user.id_utilisateur:
            raise HTTPException(status_code=403, detail="Accès non autorisé")

    from app.models.autorisation import AutorisationExceptionnelle
    from app.models.enums import StatutAutorisationEnum

    # Get all interventions for this technician
    query = (
        db.query(Intervention)
        .options(
            joinedload(Intervention.technicien),
            joinedload(Intervention.panne).joinedload(Panne.machine)
        )
        .filter(Intervention.id_technicien == id_technicien)
    )

    # For TECHNICIEN: hide interventions that still need chef authorization
    if current_user.role == RoleEnum.TECHNICIEN:
        # Join with AutorisationExceptionnelle and filter those that ARE NOT in EN_ATTENTE
        # Outer join because some interventions don't have an authorization record (fallback)
        from sqlalchemy import or_
        query = query.outerjoin(AutorisationExceptionnelle).filter(
            or_(
                AutorisationExceptionnelle.id_autorisation == None,
                AutorisationExceptionnelle.statut != StatutAutorisationEnum.EN_ATTENTE
            )
        )

    return query.all()




@router_interventions.post(
    "/create",
    response_model=InterventionDetailResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer une intervention manuellement",
)
async def creer_intervention(
    data: InterventionCreate,
    current_user=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db),
):
    """
    🔒 ADMIN, CHEF - Créer une intervention manuellement.

    À utiliser uniquement pour les affectations manuelles ou urgentes.
    La création automatique est gérée par POST /pannes/create.
    """
    from app.models.users import ChefEquipe
    # Import local safe
    panne = db.query(Panne).filter(Panne.id_panne == data.id_panne).first()
    if not panne:
        raise HTTPException(status_code=404, detail="Panne introuvable")

    technicien = db.query(Technicien).filter(
        Technicien.id_technicien == data.id_technicien
    ).first()
    if not technicien:
        raise HTTPException(status_code=404, detail="Technicien introuvable")

    if technicien.statut == StatutTechnicienEnum.INDISPONIBLE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail="Le technicien est indisponible (absent/hors service) et ne peut pas prendre d'intervention."
        )

    if technicien.statut != StatutTechnicienEnum.DISPONIBLE:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, 
            detail=f"Le technicien est {technicien.statut.value} et ne peut pas prendre d'intervention."
        )

    # Déterminer si c'est une intervention inter-groupe (Exceptionnelle)
    # On compare le groupe du tech avec le groupe principal de la machine
    id_groupe_machine_tech_principal = panne.machine.groupe_machine.id_groupe_tech_principal
    is_inter_groupe = technicien.id_groupe_principal != id_groupe_machine_tech_principal

    # Vérification de compétence
    if is_inter_groupe:
        from app.models.competence import CompetenceTechnicien
        has_competence = db.query(CompetenceTechnicien).filter(
            CompetenceTechnicien.id_technicien == technicien.id_technicien,
            CompetenceTechnicien.id_groupe_machine == panne.machine.id_groupe_machine
        ).first() is not None
        
        if not has_competence:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Le technicien {technicien.utilisateur.prenom} {technicien.utilisateur.nom} n'a pas les compétences requises pour ce groupe de machine."
            )

    # Si c'est inter-groupe, le type devient URGENTE (Exceptionnelle)
    type_final = TypeAffectationEnum.URGENTE if is_inter_groupe else data.type_affectation

    from app.models.autorisation import AutorisationExceptionnelle
    from app.models.users import ChefEquipe
    from app.utils import notification_manager

    # ── Système LEONI : Chaque intervention INTER-GROUPE doit être validée par le chef d'équipe ──
    intervention = Intervention(
        id_panne=data.id_panne,
        id_technicien=data.id_technicien,
        type_affectation=TypeAffectationEnum.URGENTE if is_inter_groupe else data.type_affectation,
        date_debut=data.date_debut or datetime.utcnow(),
        statut=StatutInterventionEnum.EN_ATTENTE
    )
    db.add(intervention)
    db.flush()  # Pour avoir l'ID de l'intervention

    if is_inter_groupe:
        # Trouver le chef d'équipe du groupe du technicien
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
            db.refresh(intervention)

            # Notifier le chef d'équipe
            await notification_manager.notifier_chef_equipe_autorisation(
                chef_id=chef.id_utilisateur,
                panne_id=data.id_panne,
                technicien_nom=f"{technicien.utilisateur.prenom} {technicien.utilisateur.nom}",
                fcm_token=None,
                db_session=db
            )
        else:
            # Bloquer si pas de chef d'équipe pour l'inter-groupe
            db.delete(intervention)
            db.commit()
            raise HTTPException(
                status_code=400,
                detail=f"Aucun chef d'équipe trouvé pour le groupe de {technicien.utilisateur.prenom} {technicien.utilisateur.nom}. Affectation inter-groupe impossible."
            )
    else:
        # Même groupe : affectation directe
        intervention.statut = StatutInterventionEnum.EN_ATTENTE # Le tech doit accepter
        panne.statut = StatutPanneEnum.EN_COURS
        technicien.statut = StatutTechnicienEnum.EN_INTERVENTION
        db.commit()

        # Notifier le technicien directement
        await notification_manager.notifier_technicien_panne(
            technicien_id=technicien.id_technicien,
            technicien_nom=f"{technicien.utilisateur.prenom} {technicien.utilisateur.nom}",
            panne_id=panne.id_panne,
            machine_nom=panne.machine.nom,
            machine_localisation=panne.machine.localisation,
            type_panne="Affectation Manuelle",
            gravite=panne.gravite.value if panne.gravite else "normale",
            priorite=panne.priorite,
            type_affectation="manuelle",
            db_session=db
        )

    return intervention



@router_interventions.put(
    "/{id_intervention}",
    response_model=InterventionResponse,
    summary="Modifier une intervention",
)
async def modifier_intervention(
    id_intervention: int,
    data: InterventionUpdate,
    current_user=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF - Modifier le type d'affectation ou la date de fin"""
    intervention = db.query(Intervention).filter(
        Intervention.id_intervention == id_intervention
    ).first()
    if not intervention:
        raise HTTPException(status_code=404, detail=f"Intervention id={id_intervention} introuvable.")

    if data.type_affectation is not None:
        intervention.type_affectation = data.type_affectation
    if data.date_fin is not None:
        intervention.date_fin = data.date_fin

    db.commit()
    db.refresh(intervention)
    return intervention



@router_interventions.put(
    "/{id_intervention}/terminer",
    response_model=TerminerInterventionResponse,
    summary="Terminer une intervention",
)
async def terminer_intervention(
    id_intervention: int,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.TECHNICIEN
    )),
    db: Session = Depends(get_db),
):
    """
    🔒 ADMIN, CHEF, TECHNICIEN - Terminer une intervention.

    - Enregistre date_fin
    - Remet le technicien en DISPONIBLE
    - Marque la panne en RESOLUE
    """
    intervention = (
        db.query(Intervention)
        .options(joinedload(Intervention.technicien), joinedload(Intervention.panne))
        .filter(Intervention.id_intervention == id_intervention)
        .first()
    )
    if not intervention:
        raise HTTPException(status_code=404, detail=f"Intervention id={id_intervention} introuvable.")

    if intervention.date_fin is not None or intervention.statut == StatutInterventionEnum.TERMINEE:
        return TerminerInterventionResponse(
            message=f"Intervention #{id_intervention} déjà terminée.",
            id_intervention=intervention.id_intervention,
            date_debut=intervention.date_debut,
            date_fin=intervention.date_fin,
            duree_minutes=intervention.duree,
        )

    if current_user.role == RoleEnum.TECHNICIEN:
        if intervention.technicien.id_utilisateur != current_user.id_utilisateur:
            raise HTTPException(status_code=403, detail="Vous ne pouvez terminer que vos propres interventions.")

    intervention.date_fin = datetime.utcnow()
    intervention.statut = StatutInterventionEnum.TERMINEE
    intervention.technicien.statut = StatutTechnicienEnum.DISPONIBLE
    intervention.technicien.date_dernier_statut = datetime.utcnow()
    
    # ── Vérifier si c'est la dernière intervention active pour cette panne ──
    autres_actives = db.query(Intervention).filter(
        Intervention.id_panne == intervention.id_panne,
        Intervention.id_intervention != id_intervention,
        Intervention.statut.in_([StatutInterventionEnum.ACCEPTEE, StatutInterventionEnum.EN_COURS, StatutInterventionEnum.EN_ATTENTE])
    ).first()
    
    if not autres_actives:
        intervention.panne.statut = StatutPanneEnum.RESOLUE
        db.commit() # Commit to ensure status is saved before archiving
        stats_util.archive_panne_history(db, intervention.id_panne)
    else:
        print(f"DEBUG: Panne {intervention.id_panne} reste EN_COURS car d'autres techniciens sont dessus.")

    db.commit()
    db.refresh(intervention)

    # Update stats
    stats_util.update_tech_stats(db, intervention.id_technicien)

    # Tenter une nouvelle affectation auto car le tech est libre
    await assigner_panne_en_attente_si_possible(db, intervention.id_technicien)

    return TerminerInterventionResponse(
        message=f"Intervention #{id_intervention} terminée avec succès.",
        id_intervention=intervention.id_intervention,
        date_debut=intervention.date_debut,
        date_fin=intervention.date_fin,
        duree_minutes=intervention.duree,
    )


@router_interventions.put("/{id_intervention}/accepter", response_model=InterventionDetailResponse)
async def accepter_intervention(
    id_intervention: int,
    current_user=Depends(require_role(RoleEnum.TECHNICIEN, RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db),
):
    """✅ TECHNICIEN - Accepter une intervention"""
    intervention = db.query(Intervention).options(
        joinedload(Intervention.technicien),
        joinedload(Intervention.panne).joinedload(Panne.machine)
    ).filter(Intervention.id_intervention == id_intervention).first()

    if not intervention:
        raise HTTPException(status_code=404, detail="Intervention introuvable")

    # Check unauthorized
    if current_user.role == RoleEnum.TECHNICIEN:
        if intervention.technicien.id_utilisateur != current_user.id_utilisateur:
            raise HTTPException(status_code=403, detail="Non autorisé")

    # Robust status check
    current_status = str(intervention.statut).lower()
    allowed_statuses = (
        StatutInterventionEnum.EN_ATTENTE,
        StatutInterventionEnum.ACCEPTEE,
        "en_attente",
        "acceptee",
        "statutinterventionenum.en_attente",
        "statutinterventionenum.acceptee"
    )

    if intervention.statut not in allowed_statuses and current_status not in allowed_statuses:
        raise HTTPException(
            status_code=400,
            detail=f"L'intervention n'est pas en attente (ID:{id_intervention}, Statut:{intervention.statut})"
        )

    # Plus d'autorisation nécessaire (Bypass LEONI)

    intervention.statut = StatutInterventionEnum.ACCEPTEE
    intervention.date_acceptation = datetime.utcnow()
    # On confirme le statut du technicien et on met la panne EN_COURS
    intervention.technicien.statut = StatutTechnicienEnum.EN_INTERVENTION
    intervention.technicien.date_dernier_statut = datetime.utcnow()
    if intervention.panne:
        intervention.panne.statut = StatutPanneEnum.EN_COURS

    db.commit()
    db.refresh(intervention)
    return intervention


@router_interventions.put("/{id_intervention}/demarrer", response_model=InterventionDetailResponse)
async def demarrer_intervention(
    id_intervention: int,
    qr_code: str,
    current_user=Depends(require_role(RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db),
):
    """✅ TECHNICIEN - Démarrer une intervention (après scan QR)"""
    intervention = db.query(Intervention).options(joinedload(Intervention.panne).joinedload(Panne.machine)).filter(Intervention.id_intervention == id_intervention).first()
    if not intervention:
        raise HTTPException(status_code=404, detail="Intervention introuvable")

    if intervention.technicien.id_utilisateur != current_user.id_utilisateur:
        raise HTTPException(status_code=403, detail="Non autorisé")

    # Plus de flexibilité : on accepte si le code stocké est dans le code scanné (ex: URL contenant l'ID)
    stored_qr = intervention.panne.machine.qr_code
    if stored_qr != qr_code and stored_qr not in qr_code:
        raise HTTPException(
            status_code=400,
            detail=f"Code QR invalide. Attendu: {stored_qr}, Scanné: {qr_code}"
        )

    intervention.statut = StatutInterventionEnum.EN_COURS
    intervention.date_scan_qr = datetime.utcnow()
    db.commit()
    db.refresh(intervention)
    return intervention


@router_interventions.post("/{id_intervention}/rapport", response_model=RapportPanneResponse)
async def soumettre_rapport(
    id_intervention: int,
    rapport_data: RapportPanneCreate,
    current_user=Depends(require_role(RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db),
):
    """✅ TECHNICIEN - Soumettre le rapport final (Bon de travail)"""
    intervention = db.query(Intervention).filter(Intervention.id_intervention == id_intervention).first()
    if not intervention:
        raise HTTPException(status_code=404, detail="Intervention introuvable")

    if intervention.technicien.id_utilisateur != current_user.id_utilisateur:
        raise HTTPException(status_code=403, detail="Non autorisé")

    # Autoriser la soumission si l'intervention est ACCEPTEE ou EN_COURS ou TERMINEE
    allowed_for_rapport = [
        StatutInterventionEnum.ACCEPTEE,
        StatutInterventionEnum.EN_COURS,
        StatutInterventionEnum.TERMINEE
    ]
    if intervention.statut not in allowed_for_rapport:
        raise HTTPException(
            status_code=400, 
            detail=f"L'intervention est en statut {intervention.statut.value}. Elle doit être acceptée, en cours ou terminée pour soumettre un rapport."
        )

    # Gérer le rapport (Création ou Mise à jour si déjà existant)
    try:
        existing_rapport = db.query(RapportPanne).filter(RapportPanne.id_intervention == id_intervention).first()
        
        if existing_rapport:
            # Mise à jour
            for key, value in rapport_data.dict().items():
                setattr(existing_rapport, key, value)
            existing_rapport.date_rapport = datetime.utcnow()
            final_rapport = existing_rapport
        else:
            # Création
            new_rapport = RapportPanne(
                id_intervention=id_intervention,
                **rapport_data.dict()
            )
            db.add(new_rapport)
            final_rapport = new_rapport

        # Mettre à jour l'intervention pour la clôturer
        intervention.statut = StatutInterventionEnum.TERMINEE
        intervention.date_fin = datetime.utcnow()

        # 1. Libérer le technicien
        if intervention.technicien:
            intervention.technicien.statut = StatutTechnicienEnum.DISPONIBLE
            intervention.technicien.date_dernier_statut = datetime.utcnow()

        # 2. Marquer la panne comme RÉSOLUE uniquement si c'est le dernier technicien
        if intervention.panne:
            autres_actives = db.query(Intervention).filter(
                Intervention.id_panne == intervention.id_panne,
                Intervention.id_intervention != id_intervention,
                Intervention.statut.in_([StatutInterventionEnum.ACCEPTEE, StatutInterventionEnum.EN_COURS, StatutInterventionEnum.EN_ATTENTE])
            ).first()
            
            if not autres_actives:
                intervention.panne.statut = StatutPanneEnum.RESOLUE
                db.commit() # Commit before archiving
                stats_util.archive_panne_history(db, intervention.id_panne)
            else:
                print(f"DEBUG: Panne {intervention.id_panne} reste EN_COURS car d'autres techniciens sont dessus.")

        db.commit()
        db.refresh(final_rapport)
        
        # Update stats
        stats_util.update_tech_stats(db, intervention.id_technicien)

        # Tenter une nouvelle affectation auto car le tech est libre
        await assigner_panne_en_attente_si_possible(db, intervention.id_technicien)

        return final_rapport
    except Exception as e:
        db.rollback()
        import traceback
        print(f"ERREUR lors de la soumission du rapport: {e}")
        traceback.print_exc()
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors de l'enregistrement du rapport: {str(e)}"
        )


@router_interventions.put("/{id_intervention}/annuler")
async def annuler_intervention(
    id_intervention: int,
    current_user=Depends(require_role(RoleEnum.TECHNICIEN, RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db),
):
    """✅ TECHNICIEN/CHEF/ADMIN - Annuler une intervention"""
    intervention = db.query(Intervention).options(
        joinedload(Intervention.technicien),
        joinedload(Intervention.panne)
    ).filter(Intervention.id_intervention == id_intervention).first()
    
    if not intervention:
        # Idempotence: si l'intervention est déjà supprimée/annulée, on renvoie succès
        return {"message": "Intervention déjà annulée ou introuvable"}
    
    # Technicien peut uniquement annuler ses propres interventions
    if current_user.role == RoleEnum.TECHNICIEN:
        if intervention.technicien.id_utilisateur != current_user.id_utilisateur:
            raise HTTPException(status_code=403, detail="Non autorisé")
    
    if intervention.statut == StatutInterventionEnum.TERMINEE:
        raise HTTPException(status_code=400, detail="Impossible d'annuler une intervention terminée")
    
    if intervention.statut == StatutInterventionEnum.ANNULEE:
        return {"message": "Intervention déjà annulée"}

    # Remettre le technicien disponible
    intervention.technicien.statut = StatutTechnicienEnum.DISPONIBLE
    intervention.technicien.date_dernier_statut = datetime.utcnow()
    # Remettre la panne en attente
    intervention.panne.statut = StatutPanneEnum.EN_ATTENTE
    # Marquer l'intervention comme annulée
    intervention.statut = StatutInterventionEnum.ANNULEE
    intervention.date_fin = datetime.utcnow()
    
    db.commit()
    
    # Tenter une nouvelle affectation auto car le tech est libre
    await assigner_panne_en_attente_si_possible(db, intervention.id_technicien)

    return {"message": "Intervention annulée avec succès"}


@router_interventions.delete(
    "/{id_intervention}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Supprimer une intervention",
)
async def supprimer_intervention(
    id_intervention: int,
    current_user=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF - Supprimer une intervention ou une panne en attente"""
    if id_intervention < 0:
        # C'est une panne virtuelle (non encore assignée)
        id_panne = -id_intervention
        panne = db.query(Panne).filter(Panne.id_panne == id_panne).first()
        if not panne:
            raise HTTPException(status_code=404, detail=f"Panne id={id_panne} introuvable.")
        
        db.delete(panne)
        db.commit()
        return

    intervention = db.query(Intervention).filter(
        Intervention.id_intervention == id_intervention
    ).first()
    if not intervention:
        raise HTTPException(status_code=404, detail=f"Intervention id={id_intervention} introuvable.")

    id_tech = intervention.id_technicien
    panne = intervention.panne

    # Libérer le technicien
    if intervention.technicien:
        intervention.technicien.statut = StatutTechnicienEnum.DISPONIBLE
        intervention.technicien.date_dernier_statut = datetime.utcnow()

    # Remettre la panne en attente si c'était la seule intervention active
    if panne:
        autres_actives = db.query(Intervention).filter(
            Intervention.id_panne == panne.id_panne,
            Intervention.id_intervention != id_intervention,
            Intervention.statut.in_([StatutInterventionEnum.EN_ATTENTE, StatutInterventionEnum.ACCEPTEE, StatutInterventionEnum.EN_COURS])
        ).first()
        
        if not autres_actives:
            panne.statut = StatutPanneEnum.EN_ATTENTE

    db.delete(intervention)
    db.commit()

    # Si le technicien est maintenant libre, tenter une nouvelle affectation
    if id_tech:
        await assigner_panne_en_attente_si_possible(db, id_tech)

    return


@router_interventions.get(
    "/autorisations/pending",
    summary="Autorisations exceptionnelles en attente (Chef d'Équipe)",
)
async def lister_autorisations_en_attente(
    current_user=Depends(require_role(RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db),
):
    """🔒 CHEF, ADMIN - Liste des demandes d'autorisation exceptionnelle en attente"""
    from app.models.autorisation import AutorisationExceptionnelle
    from sqlalchemy.orm import joinedload
    # Removed local Enum imports

    query = db.query(AutorisationExceptionnelle).options(
        joinedload(AutorisationExceptionnelle.intervention).joinedload(Intervention.technicien).joinedload(Technicien.utilisateur),
        joinedload(AutorisationExceptionnelle.intervention).joinedload(Intervention.panne).joinedload(Panne.machine),
    ).filter(AutorisationExceptionnelle.statut == StatutAutorisationEnum.EN_ATTENTE)

    # Restriction pour CHEF_EQUIPE
    if current_user.role == RoleEnum.CHEF_EQUIPE:
        from app.models.users import ChefEquipe
        chef = db.query(ChefEquipe).filter(ChefEquipe.id_utilisateur == current_user.id_utilisateur).first()
        if chef:
            query = query.filter(AutorisationExceptionnelle.id_chef_equipe == chef.id_chef)
        else:
            return []

    autorisations = query.all()
    result = []
    for a in autorisations:
        if not a.intervention:
            continue
            
        tech = a.intervention.technicien
        panne = a.intervention.panne
        result.append({
            "id_autorisation": a.id_autorisation,
            "id_intervention": a.id_intervention,
            "statut_autorisation": a.statut.value,
            "technicien": {
                "id": tech.id_technicien,
                "nom": tech.utilisateur.nom,
                "prenom": tech.utilisateur.prenom,
                "groupe_principal": tech.id_groupe_principal,
            } if tech else None,
            "machine": {
                "id": panne.machine.id_machine,
                "nom": panne.machine.nom,
                "localisation": panne.machine.localisation,
            } if panne and panne.machine else None,
            "panne": {
                "id": panne.id_panne,
                "priorite": panne.priorite,
                "statut": panne.statut.value,
            } if panne else None,
        })
    return result


@router_interventions.put(
    "/{id_intervention}/autoriser",
    summary="Approuver ou rejeter une affectation exceptionnelle (Chef d'Équipe)",
)
async def autoriser_intervention(
    id_intervention: int,
    approuver: bool,
    current_user=Depends(require_role(RoleEnum.CHEF_EQUIPE, RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db),
):
    """🔒 CHEF, ADMIN - Approuver ou rejeter une intervention exceptionnelle"""
    from app.models.autorisation import AutorisationExceptionnelle
    from app.utils import notification_manager
    # Removed local Enum imports

    intervention = db.query(Intervention).options(
        joinedload(Intervention.technicien).joinedload(Technicien.utilisateur),
        joinedload(Intervention.panne).joinedload(Panne.machine),
    ).filter(Intervention.id_intervention == id_intervention).first()

    if not intervention:
        raise HTTPException(status_code=404, detail="Intervention introuvable")

    autorisation = db.query(AutorisationExceptionnelle).filter(
        AutorisationExceptionnelle.id_intervention == id_intervention
    ).first()

    if not autorisation:
        raise HTTPException(status_code=404, detail="Aucune autorisation trouvée pour cette intervention")

    if autorisation.statut != StatutAutorisationEnum.EN_ATTENTE:
        raise HTTPException(status_code=400, detail=f"Cette autorisation a déjà été traitée: {autorisation.statut.value}")

    if approuver:
        # ── Approbation: activer l'intervention pour le technicien ───────────
        autorisation.statut = StatutAutorisationEnum.APPROUVEE
        intervention.statut = StatutInterventionEnum.EN_ATTENTE
        intervention.panne.statut = StatutPanneEnum.EN_COURS
        # On ne force pas le statut EN_INTERVENTION ici, le tech devra accepter
        db.commit()

        tech = intervention.technicien
        panne = intervention.panne
        machine = panne.machine if panne else None
        await notification_manager.notifier_technicien_panne(
            technicien_id=tech.id_technicien,
            technicien_nom=f"{tech.utilisateur.prenom} {tech.utilisateur.nom}",
            panne_id=panne.id_panne if panne else 0,
            machine_nom=machine.nom if machine else "N/A",
            machine_localisation=machine.localisation if machine else "N/A",
            type_panne="Intervention Exceptionnelle",
            gravite="haute",
            priorite=panne.priorite if panne else 1,
            type_affectation="exceptionnelle",
            db_session=db
        )
        return {"message": "Intervention approuvée. Le technicien a été notifié.", "statut": "approuvee"}

    else:
        # ── Rejet: annuler l'intervention, remettre la panne en attente ──────
        autorisation.statut = StatutAutorisationEnum.REFUSEE
        intervention.statut = StatutInterventionEnum.ANNULEE
        intervention.panne.statut = StatutPanneEnum.EN_ATTENTE
        intervention.date_fin = datetime.utcnow()
        db.commit()
        return {"message": "Intervention rejetée. La panne est remise en attente.", "statut": "refusee"}


@router_interventions.post("/{id_intervention}/renfort")
async def demander_renfort(
    id_intervention: int,
    current_user=Depends(require_role(RoleEnum.TECHNICIEN)),
    db: Session = Depends(get_db),
):
    """✅ TECHNICIEN - Demander un renfort pour l'intervention actuelle"""
    # 1. Vérifier l'intervention source
    intervention_source = db.query(Intervention).filter(Intervention.id_intervention == id_intervention).first()
    if not intervention_source:
        raise HTTPException(status_code=404, detail="Intervention source introuvable")

    if intervention_source.technicien.id_utilisateur != current_user.id_utilisateur:
        raise HTTPException(status_code=403, detail="Vous ne pouvez demander du renfort que pour vos propres interventions")

    if intervention_source.statut not in [StatutInterventionEnum.EN_COURS, StatutInterventionEnum.ACCEPTEE]:
        raise HTTPException(status_code=400, detail="L'intervention doit être en cours pour demander du renfort")

    # Éviter les doublons : vérifier qu'une demande de renfort n'est pas déjà en attente
    renfort_existant = db.query(Intervention).filter(
        Intervention.id_panne == intervention_source.id_panne,
        Intervention.type_affectation == TypeAffectationEnum.RENFORT,
        Intervention.statut == StatutInterventionEnum.EN_ATTENTE,
    ).first()
    if renfort_existant:
        return {
            "statut": "deja_en_attente",
            "message": "Une demande de renfort est déjà en attente pour cette intervention.",
            "id_intervention_renfort": renfort_existant.id_intervention,
        }

    # 2. Chercher un technicien optimal pour cette machine
    from app.utils.panne_util import selectionner_technicien_optimal
    from app.models.enums import StatutTechnicienEnum, TypeAffectationEnum as TAE
    from app.utils import notification_manager
    from app.models.users import Technicien

    panne = intervention_source.panne
    machine = panne.machine

    # Recherche d'un technicien libre (différent de l'actuel)
    tech_optimal, type_aff = selectionner_technicien_optimal(db, machine.id_machine)

    if not tech_optimal or tech_optimal.id_technicien == intervention_source.id_technicien:
        # Tenter une recherche plus large si le premier est lui-même
        tech_optimal = db.query(Technicien).filter(
            Technicien.statut == StatutTechnicienEnum.DISPONIBLE,
            Technicien.id_technicien != intervention_source.id_technicien
        ).first()

    if not tech_optimal:
        # ── Aucun technicien disponible : créer une demande EN_ATTENTE ──────
        # Elle sera auto-assignée dès qu'un technicien deviendra disponible
        intervention_renfort_pending = Intervention(
            id_panne=panne.id_panne,
            id_technicien=intervention_source.id_technicien,  # Technicien demandeur (temp)
            type_affectation=TypeAffectationEnum.RENFORT,
            statut=StatutInterventionEnum.EN_ATTENTE,
            date_debut=datetime.utcnow()
        )
        db.add(intervention_renfort_pending)
        db.commit()
        db.refresh(intervention_renfort_pending)

        # Notifier le chef d'équipe qu'un renfort est demandé mais aucun tech dispo
        from app.models.users import ChefEquipe
        chef = db.query(ChefEquipe).filter(
            ChefEquipe.id_groupe_supervise == intervention_source.technicien.id_groupe_principal
        ).first()
        if chef:
            from app.utils import notification_manager as nm
            await nm.ws_manager.send(chef.id_utilisateur, {
                "type": "RENFORT_EN_ATTENTE",
                "message": f"⚠️ Renfort requis sur Machine {machine.nom} — Aucun technicien disponible actuellement. Affectation automatique dès qu'un technicien sera libre.",
                "id_panne": panne.id_panne,
                "machine": machine.nom,
            })

        return {
            "statut": "en_attente",
            "message": "Aucun technicien disponible actuellement. Le renfort sera affecté automatiquement dès qu'un technicien deviendra libre.",
            "id_intervention_renfort": intervention_renfort_pending.id_intervention,
        }

    # 3. Technicien trouvé : Créer l'intervention de renfort directement
    nouvelle_intervention = Intervention(
        id_panne=panne.id_panne,
        id_technicien=tech_optimal.id_technicien,
        type_affectation=TypeAffectationEnum.RENFORT,
        statut=StatutInterventionEnum.EN_ATTENTE,
        date_debut=datetime.utcnow()
    )

    db.add(nouvelle_intervention)
    db.commit()
    db.refresh(nouvelle_intervention)

    # 4. Système LEONI : Chaque renfort INTER-GROUPE doit être validée par le chef d'équipe
    from app.models.autorisation import AutorisationExceptionnelle
    from app.models.enums import StatutAutorisationEnum

    # Vérifier si c'est inter-groupe
    id_groupe_machine_tech_principal = machine.groupe_machine.id_groupe_tech_principal
    is_inter_groupe = tech_optimal.id_groupe_principal != id_groupe_machine_tech_principal

    if is_inter_groupe:
        # Trouver le chef d'équipe du groupe du technicien de renfort
        chef = db.query(ChefEquipe).filter(
            ChefEquipe.id_groupe_supervise == tech_optimal.id_groupe_principal
        ).first()

        if chef:
            autorisation = AutorisationExceptionnelle(
                id_intervention=nouvelle_intervention.id_intervention,
                id_chef_equipe=chef.id_chef,
                statut=StatutAutorisationEnum.EN_ATTENTE
            )
            db.add(autorisation)
            db.commit()

            # Notifier le chef d'équipe
            await notification_manager.notifier_chef_equipe_autorisation(
                chef_id=chef.id_utilisateur,
                panne_id=panne.id_panne,
                technicien_nom=f"{tech_optimal.utilisateur.prenom} {tech_optimal.utilisateur.nom}",
                fcm_token=None,
                db_session=db
            )
        else:
            # Bloquer si pas de chef d'équipe pour l'inter-groupe
            db.delete(nouvelle_intervention)
            db.commit()
            raise HTTPException(
                status_code=400,
                detail=f"Aucun chef d'équipe trouvé pour le groupe de {tech_optimal.utilisateur.prenom} {tech_optimal.utilisateur.nom}. Renfort inter-groupe impossible."
            )
    else:
        # Même groupe : affectation directe
        nouvelle_intervention.statut = StatutInterventionEnum.EN_ATTENTE # Le tech doit accepter
        panne.statut = StatutPanneEnum.EN_COURS
        tech_optimal.statut = StatutTechnicienEnum.EN_INTERVENTION
        db.commit()

        # Notifier le technicien directement
        await notification_manager.notifier_technicien_panne(
            technicien_id=tech_optimal.id_technicien,
            technicien_nom=f"{tech_optimal.utilisateur.prenom} {tech_optimal.utilisateur.nom}",
            panne_id=panne.id_panne,
            machine_nom=machine.nom,
            machine_localisation=machine.localisation,
            type_panne="Renfort Intra-groupe",
            gravite=panne.gravite.value if panne.gravite else "normale",
            priorite=panne.priorite,
            type_affectation="renfort",
            db_session=db
        )

    return nouvelle_intervention

