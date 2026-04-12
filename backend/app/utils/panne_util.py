"""
Service d'Affectation Automatique - Système LEONI
Sélectionne le technicien optimal selon :
  1. Compétences sur le groupe machine
  2. Statut DISPONIBLE
  3. Ordre FIFO (moins d'interventions en cours)
  4. Proximité géographique (si position disponible)
"""

import math
import logging
from sqlalchemy.orm import Session
from datetime import datetime
from typing import Optional

from app.models.users import Technicien, Utilisateur
from app.models.competence import CompetenceTechnicien
from app.models.machine import Machine, GroupeMachine
from app.models.enums import StatutTechnicienEnum, TypeAffectationEnum

logger = logging.getLogger(__name__)


def _distance_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Calcul de distance Haversine entre deux coordonnées GPS"""
    R = 6371
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(
        math.radians(lat2)
    ) * math.sin(dlng / 2) ** 2
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))


def selectionner_technicien_optimal(
    db: Session,
    id_machine: int,
    machine_lat: Optional[float] = None,
    machine_lng: Optional[float] = None,
) -> tuple[Optional[Technicien], TypeAffectationEnum]:
    """
    Retourne (technicien_optimal, type_affectation) selon les règles LEONI :
      1. Groupe principal de la machine (A -> X, B -> Y, C -> Z)
      2. FIFO (Longest available) + Proximité
      3. Si manque de tech : Extension aux autres groupes avec autorisation
    """
    # 1. Récupérer la machine et son groupe
    machine = db.query(Machine).filter(Machine.id_machine == id_machine).first()
    if not machine:
        return None, TypeAffectationEnum.AUTOMATIQUE

    groupe_machine = machine.groupe_machine
    if not groupe_machine:
        return None, TypeAffectationEnum.AUTOMATIQUE

    # ── Étape 1 : Chercher dans le groupe principal ───────────────────────────
    id_groupe_tech_principal = groupe_machine.id_groupe_tech_principal
    print(f"DEBUG: Selecting tech for Machine {id_machine} (Group Req {id_groupe_tech_principal})")
    candidats_principaux = (
        db.query(Technicien)
        .filter(
            Technicien.id_groupe_principal == id_groupe_tech_principal,
            Technicien.statut == StatutTechnicienEnum.DISPONIBLE,
        )
        .all()
    )
    print(f"DEBUG: Found {len(candidats_principaux)} candidates in group")
    for c in candidats_principaux:
        print(f"DEBUG: Candidate {c.id_technicien} (Statut: {c.statut})")

    def calculer_score(tech: Technicien) -> float:
        """Score bas = meilleur. Mélange FIFO (temps d'attente) et Proximité."""
        # FIFO : Secondes depuis le dernier changement de statut (plus grand = plus de temps libre)
        # On veut privilégier celui qui attend depuis le plus longtemps.
        attente_score = 0
        if tech.date_dernier_statut:
            delta = (datetime.utcnow() - tech.date_dernier_statut).total_seconds()
            # On soustrait l'attente pour que le score baisse avec le temps d'attente
            attente_score = -delta / 3600  # -1 point par heure d'attente
        
        distance = 0.0
        if (machine_lat and machine_lng and tech.position_lat and tech.position_lng):
            distance = _distance_km(float(tech.position_lat), float(tech.position_lng), 
                                  machine_lat, machine_lng)
        
        return attente_score + distance

    if candidats_principaux:
        meilleur = min(candidats_principaux, key=calculer_score)
        return meilleur, TypeAffectationEnum.AUTOMATIQUE

    # ── Étape 2 : Extension intelligente (Manque de techniciens) ──────────────
    # Chercher les techniciens d'autres groupes ayant la compétence machine
    competent_ids = (
        db.query(CompetenceTechnicien.id_technicien)
        .filter(CompetenceTechnicien.id_groupe_machine == machine.id_groupe_machine)
        .all()
    )
    competent_ids = [cid[0] for cid in competent_ids]

    candidats_extension = (
        db.query(Technicien)
        .filter(
            Technicien.id_technicien.in_(competent_ids),
            Technicien.id_groupe_principal != id_groupe_tech_principal,
            Technicien.statut == StatutTechnicienEnum.DISPONIBLE,
        )
        .all()
    )

    # Filtrer par "nombre minimum de techniciens libres" dans le groupe d'origine
    candidats_valides = []
    for tech in candidats_extension:
        groupe_origine = tech.groupe_principal
        if not groupe_origine: continue
        
        # Compter techniciens libres dans son groupe
        libres_dans_groupe = db.query(Technicien).filter(
            Technicien.id_groupe_principal == groupe_origine.id_groupe_tech,
            Technicien.statut == StatutTechnicienEnum.DISPONIBLE
        ).count()
        
        if libres_dans_groupe > groupe_origine.nombre_min_dispo:
            candidats_valides.append(tech)

    if candidats_valides:
        meilleur = min(candidats_valides, key=calculer_score)
        return meilleur, TypeAffectationEnum.URGENTE # Sera marqué pour autorisation

    # ── Étape 3 : Dernier recours (Urgence absolue sans quota) ──────────────
    # Si aucun technicien "sûr" n'est trouvé, on prend n'importe quel technicien disponible avec la compétence
    if candidats_extension:
        meilleur = min(candidats_extension, key=calculer_score)
        return meilleur, TypeAffectationEnum.URGENTE

    return None, TypeAffectationEnum.AUTOMATIQUE


async def assigner_panne_en_attente_si_possible(db: Session, id_technicien: int):
    """
    Système LEONI : Tentative d'affectation automatique d'une panne en attente 
    lorsqu'un technicien devient libre.
    Gère aussi les demandes de renfort "orphelines" (sans technicien réel assigné).
    """
    from app.models.panne import Panne
    from app.models.intervention import Intervention
    from app.models.enums import StatutPanneEnum, StatutInterventionEnum, TypeAffectationEnum, StatutTechnicienEnum
    from app.utils import notification_manager

    # 1. Vérifier si le technicien est vraiment libre
    tech = db.query(Technicien).filter(Technicien.id_technicien == id_technicien).first()
    if not tech or tech.statut != StatutTechnicienEnum.DISPONIBLE:
        return None

    # ── Priorité 0 : Renforts en attente (sans technicien réel) ──────────────
    # Une demande de renfort "en attente" a le même id_technicien que le demandeur
    # On cherche les renforts où le technicien assigné est en intervention (= demandeur)
    renforts_en_attente = (
        db.query(Intervention)
        .filter(
            Intervention.type_affectation == TypeAffectationEnum.RENFORT,
            Intervention.statut == StatutInterventionEnum.EN_ATTENTE,
        )
        .all()
    )

    for renfort in renforts_en_attente:
        # Un renfort "orphelin" : le technicien assigné est le demandeur (en intervention)
        tech_demandeur = db.query(Technicien).filter(
            Technicien.id_technicien == renfort.id_technicien
        ).first()
        
        if tech_demandeur and tech_demandeur.statut == StatutTechnicienEnum.EN_INTERVENTION:
            # Ce renfort attend un vrai technicien libre → assigner le technicien disponible
            if renfort.id_technicien != id_technicien:  # Ne pas s'auto-assigner
                renfort.id_technicien = id_technicien
                tech.statut = StatutTechnicienEnum.EN_INTERVENTION
                tech.date_dernier_statut = datetime.utcnow()
                db.commit()

                # Notifier le technicien de renfort
                machine = renfort.panne.machine
                await notification_manager.notifier_technicien_panne(
                    technicien_id=tech.id_technicien,
                    technicien_nom=f"{tech.utilisateur.prenom} {tech.utilisateur.nom}",
                    panne_id=renfort.id_panne,
                    machine_nom=machine.nom,
                    machine_localisation=machine.localisation,
                    type_panne="Renfort (automatique)",
                    gravite=renfort.panne.gravite.value if renfort.panne.gravite else "normale",
                    priorite=renfort.panne.priorite,
                    type_affectation="renfort",
                    db_session=db
                )
                return renfort

    # 2. Chercher les pannes en attente (triées par priorité)
    from app.models.panne import Panne
    from app.models.intervention import Intervention
    from app.models.enums import StatutInterventionEnum

    pannes_raw = (
        db.query(Panne)
        .filter(Panne.statut == StatutPanneEnum.EN_ATTENTE)
        .order_by(Panne.priorite.asc(), Panne.date_declaration.asc())
        .all()
    )

    # Filtrer les pannes qui ont déjà une intervention active (déjà assignées mais pas encore passées en EN_COURS)
    pannes_en_attente = []
    for p in pannes_raw:
        has_active = db.query(Intervention).filter(
            Intervention.id_panne == p.id_panne,
            Intervention.statut.in_([StatutInterventionEnum.ACCEPTEE, StatutInterventionEnum.EN_COURS, StatutInterventionEnum.EN_ATTENTE])
        ).first() is not None
        if not has_active:
            pannes_en_attente.append(p)

    if not pannes_en_attente:
        return None
    # Priorité 1 : Même groupe
    for panne in pannes_en_attente:
        req_group = panne.machine.groupe_machine.id_groupe_tech_principal
        print(f"[DEBUG_ASSIGN] Panne {panne.id_panne} | Req Group {req_group} | Tech Group {tech.id_groupe_principal}")
        if req_group == tech.id_groupe_principal:
            return await _creer_intervention_directe(db, tech, panne, TypeAffectationEnum.AUTOMATIQUE)

    # Priorité 2 : Autre groupe avec compétence (URGENTE mais directe)
    for panne in pannes_en_attente:
        # Vérifier si le tech a la compétence pour ce groupe de machine
        has_competence = any(c.id_groupe_machine == panne.machine.id_groupe_machine for c in tech.competences)
        if has_competence:
            return await _creer_intervention_directe(db, tech, panne, TypeAffectationEnum.URGENTE)

    return None


async def _creer_intervention_directe(db: Session, tech: Technicien, panne, type_aff: TypeAffectationEnum):
    """Helper pour créer une intervention et notifier selon le type d'affectation"""
    from app.models.intervention import Intervention
    from app.models.autorisation import AutorisationExceptionnelle
    from app.models.users import ChefEquipe
    from app.models.enums import (StatutInterventionEnum, StatutPanneEnum,
                                   StatutTechnicienEnum, StatutAutorisationEnum)
    from app.utils import notification_manager

    intervention = Intervention(
        id_panne=panne.id_panne,
        id_technicien=tech.id_technicien,
        date_debut=datetime.utcnow(),
        type_affectation=type_aff,
        statut=StatutInterventionEnum.EN_ATTENTE
    )
    db.add(intervention)

    # ── Système LEONI : Chaque intervention INTER-GROUPE doit être validée par le chef d'équipe ──
    db.flush()  # Pour obtenir l'ID de l'intervention

    # SI c'est une affectation URGENTE (Inter-groupe), on demande une autorisation
    if type_aff == TypeAffectationEnum.URGENTE:
        # Chercher le chef du groupe du technicien (celui qui doit valider)
        chef = db.query(ChefEquipe).filter(
            ChefEquipe.id_groupe_supervise == tech.id_groupe_principal
        ).first()

        if chef:
            # Créer la demande d'autorisation
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
                panne_id=panne.id_panne,
                technicien_nom=f"{tech.utilisateur.prenom} {tech.utilisateur.nom}",
                fcm_token=None,
                db_session=db
            )
        else:
            # Si aucun chef n'est trouvé, on bloque par sécurité pour l'inter-groupe
            logger.warning(f"Aucun chef d'équipe trouvé pour le groupe de {tech.id_technicien}. Validation bloquée.")
            db.commit()
    else:
        # SI c'est une affectation AUTOMATIQUE (Même groupe), on valide direct
        intervention.statut = StatutInterventionEnum.EN_ATTENTE # Le tech doit toujours accepter
        panne.statut = StatutPanneEnum.EN_COURS
        tech.statut = StatutTechnicienEnum.EN_INTERVENTION
        db.commit()

        # Notifier le technicien directement (pas besoin de validation chef)
        machine = panne.machine
        await notification_manager.notifier_technicien_panne(
            technicien_id=tech.id_technicien,
            technicien_nom=f"{tech.utilisateur.prenom} {tech.utilisateur.nom}",
            panne_id=panne.id_panne,
            machine_nom=machine.nom,
            machine_localisation=machine.localisation,
            type_panne="Affectation Automatique",
            gravite=panne.gravite.value if panne.gravite else "normale",
            priorite=panne.priorite,
            type_affectation="automatique",
            db_session=db
        )

    return intervention





