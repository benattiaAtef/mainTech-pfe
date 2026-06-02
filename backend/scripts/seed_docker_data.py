import sys
import os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import random
from datetime import datetime, timedelta
from app.core.database import SessionLocal
from app.models.machine import Machine, GroupeMachine
from app.models.panne import Panne, TypePanne
from app.models.intervention import Intervention, RapportPanne
from app.models.users import Technicien
from app.models.enums import (
    StatutPanneEnum, GraviteEnum, StatutInterventionEnum,
    TypeAffectationEnum, StatutTechnicienEnum
)

def seed_docker_database():
    db = SessionLocal()
    print("Début du peuplement de la base de données (Docker)...")

    # 1. Ensure TypePanne exist
    types_pannes_data = [
        ("Moteur défectueux", GraviteEnum.HAUTE),
        ("Surchauffe système", GraviteEnum.CRITIQUE),
        ("Erreur capteur", GraviteEnum.MOYENNE),
        ("Calibration nécessaire", GraviteEnum.FAIBLE),
        ("Coupure d'alimentation", GraviteEnum.HAUTE),
        ("Fuite de fluide", GraviteEnum.MOYENNE),
        ("Composant cassé", GraviteEnum.CRITIQUE),
        ("Problème de connectivité", GraviteEnum.FAIBLE),
        ("Usure mécanique", GraviteEnum.MOYENNE)
    ]
    
    types_pannes = db.query(TypePanne).all()
    if not types_pannes:
        print("Création des TypePanne...")
        for nom, gravite in types_pannes_data:
            tp = TypePanne(nom_panne=nom, gravite=gravite)
            db.add(tp)
        db.commit()
        types_pannes = db.query(TypePanne).all()
    else:
        print(f"{len(types_pannes)} TypePanne trouvés.")

    # 2. Get existing Machines and Techniciens
    machines = db.query(Machine).all()
    if not machines:
        print("Erreur: Aucune machine trouvée dans la base de données. Impossible de générer des pannes.")
        return

    # Map groups to techniciens
    techniciens = db.query(Technicien).all()
    techs_by_group = {}
    for tech in techniciens:
        if tech.id_groupe_principal not in techs_by_group:
            techs_by_group[tech.id_groupe_principal] = []
        techs_by_group[tech.id_groupe_principal].append(tech)

    print(f"{len(machines)} Machines trouvées.")
    print(f"{len(techniciens)} Techniciens trouvés.")

    # 3. Generate 400 Pannes
    total_pannes = 400
    pannes_to_add = []
    
    # Weights for status
    status_weights = [
        (StatutPanneEnum.EN_ATTENTE, 50),
        (StatutPanneEnum.EN_COURS, 100),
        (StatutPanneEnum.A_VALIDER, 50),
        (StatutPanneEnum.RESOLUE, 200)
    ]
    
    statuses = []
    for stat, count in status_weights:
        statuses.extend([stat] * count)
    random.shuffle(statuses)

    now = datetime.utcnow()

    # Generate Pannes
    for i in range(total_pannes):
        machine = random.choice(machines)
        type_panne = random.choice(types_pannes)
        statut = statuses[i]

        # Ensure we have techniciens for this machine's group, otherwise keep it EN_ATTENTE
        gm = db.query(GroupeMachine).filter(GroupeMachine.id_groupe_machine == machine.id_groupe_machine).first()
        if not gm or not techs_by_group.get(gm.id_groupe_tech_principal):
            statut = StatutPanneEnum.EN_ATTENTE

        # Random date in the last 6 months
        days_ago = random.randint(0, 180)
        date_decl = now - timedelta(days=days_ago, hours=random.randint(0, 23), minutes=random.randint(0, 59))

        priorite = 1 if type_panne.gravite == GraviteEnum.FAIBLE else (2 if type_panne.gravite == GraviteEnum.MOYENNE else (3 if type_panne.gravite == GraviteEnum.HAUTE else 4))

        panne = Panne(
            id_machine=machine.id_machine,
            id_type_panne=type_panne.id_type_panne,
            priorite=priorite,
            statut=statut,
            id_superviseur=1,
            date_declaration=date_decl
        )
        pannes_to_add.append(panne)

    db.add_all(pannes_to_add)
    db.commit()
    print(f"{total_pannes} pannes créées avec succès.")

    # 4. Generate Interventions for Pannes not EN_ATTENTE
    pannes_creees = db.query(Panne).filter(Panne.statut != StatutPanneEnum.EN_ATTENTE).all()
    interventions_to_add = []
    rapports_to_add = []

    for panne in pannes_creees:
        machine = db.query(Machine).filter(Machine.id_machine == panne.id_machine).first()
        gm = db.query(GroupeMachine).filter(GroupeMachine.id_groupe_machine == machine.id_groupe_machine).first()
        techs = techs_by_group.get(gm.id_groupe_tech_principal, [])
        if not techs:
            continue
        tech = random.choice(techs)

        date_debut = panne.date_declaration + timedelta(minutes=random.randint(15, 120))
        
        statut_int = StatutInterventionEnum.EN_COURS
        date_fin = None
        duree = None

        if panne.statut in [StatutPanneEnum.RESOLUE, StatutPanneEnum.A_VALIDER]:
            statut_int = StatutInterventionEnum.TERMINEE
            duree_minutes = random.randint(30, 240)
            date_fin = date_debut + timedelta(minutes=duree_minutes)
            duree = float(duree_minutes)
        
        type_affect = random.choice([TypeAffectationEnum.AUTOMATIQUE, TypeAffectationEnum.MANUELLE, TypeAffectationEnum.URGENTE])

        interv = Intervention(
            id_panne=panne.id_panne,
            id_technicien=tech.id_technicien,
            date_debut=date_debut,
            date_acceptation=date_debut - timedelta(minutes=5),
            date_fin=date_fin,
            statut=statut_int,
            type_affectation=type_affect,
            duree_minutes=duree
        )
        interventions_to_add.append(interv)

    db.add_all(interventions_to_add)
    db.commit()
    print(f"{len(interventions_to_add)} interventions créées avec succès.")

    # 5. Generate Rapports for TERMINEE Interventions
    interventions_terminees = db.query(Intervention).filter(Intervention.statut == StatutInterventionEnum.TERMINEE).all()
    for interv in interventions_terminees:
        rapport = RapportPanne(
            id_intervention=interv.id_intervention,
            description_action="Remplacement des pièces défectueuses et nettoyage du système complet.",
            pieces_utilisees="Filtre x1, Vis x4, Câble x1",
            observations="La machine fonctionne normalement après le test.",
            date_rapport=interv.date_fin + timedelta(minutes=10)
        )
        rapports_to_add.append(rapport)

    db.add_all(rapports_to_add)
    db.commit()
    print(f"{len(rapports_to_add)} rapports de panne créés avec succès.")

    db.close()
    print("Opération terminée avec succès !")

if __name__ == "__main__":
    seed_docker_database()
