import sys, os
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

import random
from datetime import datetime, timedelta
from app.core.database import SessionLocal
from app.models.machine import Machine, GroupeMachine
from app.models.competence import GroupeTechnicien
from app.models.panne import Panne, TypePanne
from app.models.intervention import Intervention, RapportPanne
from app.models.users import Technicien, Utilisateur
from app.models.enums import (
    StatutPanneEnum, GraviteEnum, StatutInterventionEnum,
    TypeAffectationEnum, RoleEnum
)

def reseed():
    db = SessionLocal()

    # === Nettoyage ===
    print("Nettoyage...")
    db.query(RapportPanne).delete()
    db.query(Intervention).delete()
    db.query(Panne).delete()
    db.commit()

    # === References ===
    types_pannes = db.query(TypePanne).all()
    machines = db.query(Machine).all()
    techniciens = db.query(Technicien).all()

    superviseur = db.query(Utilisateur).filter(Utilisateur.role == RoleEnum.SUPERVISEUR).first()
    if not superviseur:
        superviseur = db.query(Utilisateur).filter(Utilisateur.role == RoleEnum.ADMINISTRATEUR).first()
    id_sup = superviseur.id_utilisateur

    techs_by_group = {}
    for t in techniciens:
        techs_by_group.setdefault(t.id_groupe_principal, []).append(t)

    gms_dict = {gm.id_groupe_machine: gm for gm in db.query(GroupeMachine).all()}

    print(f"{len(machines)} machines, {len(techniciens)} techniciens, {len(types_pannes)} types pannes")

    # === Generation: 1000 pannes RESOLUE + 1000 interventions TERMINEE ===
    now = datetime.utcnow()
    total = 1000

    descriptions_travaux = [
        "Remplacement du composant defectueux et test de validation.",
        "Nettoyage complet du systeme et recalibration des capteurs.",
        "Changement du filtre et verification du circuit hydraulique.",
        "Reparation du moteur principal et graissage des roulements.",
        "Mise a jour du firmware et reinitialisation des parametres.",
        "Soudure du joint defaillant et test de pression.",
        "Remplacement de la courroie usee et alignement.",
        "Depannage electrique: remplacement du relais defectueux.",
        "Intervention preventive: inspection et serrage des boulons.",
        "Reparation de la fuite et remplacement du joint torique.",
    ]
    descriptions_panne = [
        "La machine a arrete de fonctionner subitement.",
        "Bruit anormal detecte pendant le fonctionnement.",
        "Perte de puissance progressive.",
        "Voyant d'erreur allume sur le tableau de bord.",
        "Vibrations excessives lors du demarrage.",
        "Temperature anormalement elevee.",
        "Arret d'urgence declenche automatiquement.",
        "Dysfonctionnement du capteur de position.",
    ]
    observations_list = [
        "Machine operationnelle apres test.",
        "Fonctionnement normal retabli.",
        "A surveiller dans les 48h.",
        "Performance nominale confirmee.",
        "Recommandation: maintenance preventive dans 30 jours.",
        "RAS, machine remise en service.",
    ]
    type_travail_list = ["MCP", "MNP", "AUT"]

    created = 0
    skipped = 0

    for i in range(total):
        machine = random.choice(machines)
        type_panne = random.choice(types_pannes)

        gm = gms_dict.get(machine.id_groupe_machine)
        tech_group_id = gm.id_groupe_tech_principal if gm else None
        techs = techs_by_group.get(tech_group_id, []) if tech_group_id else []

        if not techs:
            skipped += 1
            continue

        tech = random.choice(techs)
        days_ago = random.randint(1, 365)
        date_decl = now - timedelta(days=days_ago, hours=random.randint(0, 23), minutes=random.randint(0, 59))

        priorite = {GraviteEnum.FAIBLE: 1, GraviteEnum.MOYENNE: 2, GraviteEnum.HAUTE: 3, GraviteEnum.CRITIQUE: 4}.get(type_panne.gravite, 2)

        panne = Panne(
            id_machine=machine.id_machine,
            id_type_panne=type_panne.id_type_panne,
            id_superviseur=id_sup,
            priorite=priorite,
            statut=StatutPanneEnum.RESOLUE,
            date_declaration=date_decl,
        )
        db.add(panne)
        db.flush()

        date_debut = date_decl + timedelta(minutes=random.randint(15, 120))
        duree = random.randint(30, 300)
        date_fin = date_debut + timedelta(minutes=duree)
        date_scan = date_debut + timedelta(minutes=random.randint(1, 5))

        interv = Intervention(
            id_panne=panne.id_panne,
            id_technicien=tech.id_technicien,
            date_debut=date_debut,
            date_acceptation=date_debut - timedelta(minutes=random.randint(1, 10)),
            date_scan_qr=date_scan,
            date_fin=date_fin,
            statut=StatutInterventionEnum.TERMINEE,
            type_affectation=random.choice([TypeAffectationEnum.AUTOMATIQUE, TypeAffectationEnum.MANUELLE, TypeAffectationEnum.URGENTE]),
        )
        db.add(interv)
        db.flush()

        rapport = RapportPanne(
            id_intervention=interv.id_intervention,
            description_panne=random.choice(descriptions_panne),
            travaux_effectues=random.choice(descriptions_travaux),
            type_travail=random.choice(type_travail_list),
            temps_arret=random.randint(30, 480),
            observations=random.choice(observations_list),
            causes="Usure naturelle des composants mecaniques.",
            solutions="Remplacement des pieces et recalibration.",
            etat_final="Operationnel",
            date_rapport=date_fin + timedelta(minutes=random.randint(5, 30)),
        )
        db.add(rapport)
        created += 1

        if created % 200 == 0:
            db.commit()
            print(f"  {created}/{total}...")

    db.commit()

    print(f"\n=== Resultat ===")
    print(f"  Pannes RESOLUE: {db.query(Panne).count()}")
    print(f"  Interventions TERMINEE: {db.query(Intervention).count()}")
    print(f"  Rapports: {db.query(RapportPanne).count()}")
    print(f"  Skipped (pas de technicien): {skipped}")
    db.close()
    print("Termine!")

if __name__ == "__main__":
    reseed()
