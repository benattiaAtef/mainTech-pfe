import sys
import os
import random
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.core.database import SessionLocal
from app.models.enums import *
from app.models.users import Utilisateur, Technicien, ChefEquipe, Superviseur
from app.models.machine import Machine, GroupeMachine
from app.models.competence import CompetenceTechnicien, GroupeTechnicien
from app.models.panne import TypePanne, Panne, HistoriquePanne
from app.models.intervention import Intervention, RapportPanne
from app.models.magasin import PieceRechange, DemandeRechange, StatutDemandeEnum
from app.models.autorisation import AutorisationExceptionnelle, StatistiqueTech

try:
    from faker import Faker
except ImportError:
    print("Veuillez installer faker: pip install faker")
    sys.exit(1)

fake = Faker('fr_FR')

def main():
    db = SessionLocal()
    try:
        # 1. Vérifier si on a les données de base
        machines = db.query(Machine).all()
        techniciens = db.query(Technicien).all()
        superviseurs = db.query(Superviseur).all()
        chefs_equipe = db.query(ChefEquipe).all()
        groupes_machine = db.query(GroupeMachine).all()
        
        if not machines or not techniciens or not superviseurs:
            print("Erreur: Il manque des machines, des techniciens ou des superviseurs dans la BD.")
            return

        print(f"Trouvé: {len(machines)} machines, {len(techniciens)} techniciens, {len(superviseurs)} superviseurs.")

        # 2. Créer TypePanne
        print("Création des types de pannes...")
        types_panne_noms = ["Électrique", "Mécanique", "Hydraulique", "Pneumatique", "Logiciel", "Thermique"]
        types_panne = []
        for nom in types_panne_noms:
            tp = db.query(TypePanne).filter_by(nom_panne=nom).first()
            if not tp:
                tp = TypePanne(
                    nom_panne=nom,
                    gravite=random.choice(list(GraviteEnum))
                )
                db.add(tp)
                types_panne.append(tp)
            else:
                types_panne.append(tp)
        db.commit()

        # 3. Créer PieceRechange
        print("Création du catalogue de pièces de rechange...")
        pieces = []
        for i in range(50):
            p = PieceRechange(
                reference=f"REF-{fake.unique.random_number(digits=6)}",
                nom=fake.word().capitalize() + " " + fake.word(),
                description=fake.sentence(),
                quantite_stock=random.randint(0, 100),
                unite=random.choice(["pcs", "m", "kg", "L"])
            )
            db.add(p)
            pieces.append(p)
        db.commit()

        # 4. CompetenceTechnicien
        print("Création des compétences techniciens...")
        if groupes_machine:
            for tech in techniciens:
                groupes_assignes = random.sample(groupes_machine, k=random.randint(1, min(3, len(groupes_machine))))
                for gm in groupes_assignes:
                    comp = db.query(CompetenceTechnicien).filter_by(id_technicien=tech.id_technicien, id_groupe_machine=gm.id_groupe_machine).first()
                    if not comp:
                        comp = CompetenceTechnicien(
                            id_technicien=tech.id_technicien,
                            id_groupe_machine=gm.id_groupe_machine,
                            niveau_expertise=random.choice(list(NiveauExpertiseEnum))
                        )
                        db.add(comp)
            db.commit()

        # 5. Pannes (Créer 200 pannes)
        print("Création des pannes...")
        pannes = []
        for _ in range(200):
            date_decl = fake.date_time_between(start_date="-6M", end_date="now")
            panne = Panne(
                id_machine=random.choice(machines).id_machine,
                id_type_panne=random.choice(types_panne).id_type_panne,
                id_superviseur=random.choice(superviseurs).id_superviseur,
                priorite=random.randint(1, 5),
                gravite=random.choice(list(GraviteEnum)),
                statut=random.choice(list(StatutPanneEnum)),
                date_declaration=date_decl
            )
            db.add(panne)
            pannes.append(panne)
        db.commit()

        # 6. Interventions, Rapports, Demandes
        print("Création des interventions et rapports...")
        for panne in pannes:
            if panne.statut != StatutPanneEnum.EN_ATTENTE:
                tech = random.choice(techniciens)
                date_debut = panne.date_declaration + timedelta(hours=random.randint(1, 24))
                date_accept = date_debut + timedelta(minutes=random.randint(5, 30))
                date_scan = date_accept + timedelta(minutes=random.randint(5, 15))
                date_fin = date_scan + timedelta(hours=random.randint(1, 8))
                
                statut_int = StatutInterventionEnum.TERMINEE if panne.statut == StatutPanneEnum.RESOLUE else random.choice([StatutInterventionEnum.EN_COURS, StatutInterventionEnum.ACCEPTEE])

                inter = Intervention(
                    id_panne=panne.id_panne,
                    id_technicien=tech.id_technicien,
                    date_debut=date_debut,
                    date_acceptation=date_accept if statut_int != StatutInterventionEnum.EN_ATTENTE else None,
                    date_scan_qr=date_scan if statut_int in [StatutInterventionEnum.EN_COURS, StatutInterventionEnum.TERMINEE] else None,
                    date_fin=date_fin if statut_int == StatutInterventionEnum.TERMINEE else None,
                    statut=statut_int,
                    type_affectation=random.choice(list(TypeAffectationEnum))
                )
                db.add(inter)
                db.flush()

                if statut_int == StatutInterventionEnum.TERMINEE:
                    # RapportPanne
                    rapport = RapportPanne(
                        id_intervention=inter.id_intervention,
                        description_panne=fake.text(max_nb_chars=200),
                        travaux_effectues=fake.text(max_nb_chars=200),
                        type_travail=random.choice(["MCP", "MNP", "AUT"]),
                        temps_arret=int((date_fin - panne.date_declaration).total_seconds() / 60),
                        causes=fake.sentence(),
                        solutions=fake.sentence(),
                        etat_final="Opérationnel",
                        date_rapport=date_fin
                    )
                    db.add(rapport)

                    # DemandeRechange
                    if random.random() > 0.5:
                        piece = random.choice(pieces)
                        demande = DemandeRechange(
                            id_intervention=inter.id_intervention,
                            id_piece=piece.id_piece,
                            quantite_demandee=random.randint(1, 5),
                            statut=StatutDemandeEnum.LIVREE,
                            commentaire=fake.sentence(),
                            date_demande=date_scan
                        )
                        db.add(demande)
                        
                # Autorisation Exceptionnelle
                if random.random() > 0.8 and chefs_equipe:
                    auto = AutorisationExceptionnelle(
                        id_intervention=inter.id_intervention,
                        id_chef_equipe=random.choice(chefs_equipe).id_chef,
                        statut=random.choice(list(StatutAutorisationEnum))
                    )
                    db.add(auto)
        
        db.commit()

        # 7. HistoriquePanne & StatistiqueTech
        print("Mise à jour des historiques et statistiques...")
        for machine in machines:
            hp = db.query(HistoriquePanne).filter_by(id_machine=machine.id_machine).first()
            pannes_machine = [p for p in pannes if p.id_machine == machine.id_machine]
            if pannes_machine:
                last_panne = max([p.date_declaration for p in pannes_machine])
                if not hp:
                    hp = HistoriquePanne(
                        id_panne=random.choice(pannes_machine).id_panne,
                        id_type_panne=random.choice(pannes_machine).id_type_panne,
                        id_machine=machine.id_machine,
                        frequence_panne=len(pannes_machine),
                        dernie_panne=last_panne.date()
                    )
                    db.add(hp)
        
        for tech in techniciens:
            st = db.query(StatistiqueTech).filter_by(id_technicien=tech.id_technicien).first()
            inters = db.query(Intervention).filter_by(id_technicien=tech.id_technicien, statut=StatutInterventionEnum.TERMINEE).all()
            if not st:
                st = StatistiqueTech(
                    id_technicien=tech.id_technicien,
                    nombreintervention=len(inters),
                    temps_moyen_intervention=random.uniform(60, 240) if inters else 0,
                    taux_reussite=random.uniform(80, 100) if inters else 0
                )
                db.add(st)
        
        db.commit()
        print("Base de données remplie avec succès avec des données compatibles !")

    except Exception as e:
        print(f"Erreur lors de l'insertion : {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    main()
