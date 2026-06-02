import sys
import os
import random
from datetime import datetime, timedelta

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from app.core.database import SessionLocal
from app.models.enums import (
    StatutPanneEnum,
    StatutInterventionEnum,
    GraviteEnum,
    TypeAffectationEnum,
    StatutPresenceEnum
)
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
        # 1. Check prerequisites
        machines = db.query(Machine).all()
        techniciens = db.query(Technicien).all()
        superviseurs = db.query(Superviseur).all()
        types_panne = db.query(TypePanne).all()
        pieces = db.query(PieceRechange).all()

        if not machines or not techniciens or not superviseurs or not types_panne:
            print("Erreur: Il manque des données de base (machines, techniciens, superviseurs, types_panne) dans la BD.")
            return

        print(f"Base de données existante :")
        print(f"  - Machines : {len(machines)}")
        print(f"  - Techniciens : {len(techniciens)}")
        print(f"  - Superviseurs : {len(superviseurs)}")
        print(f"  - Types de panne : {len(types_panne)}")
        print(f"  - Pièces de rechange : {len(pieces)}")

        # 2. Nettoyage de la base de données
        print("\nNettoyage de la base de données...")
        
        # Supprimer les interventions qui ne sont pas TERMINEE
        deleted_interventions = db.query(Intervention).filter(Intervention.statut != StatutInterventionEnum.TERMINEE).delete(synchronize_session=False)
        print(f"  - Interventions non-terminées supprimées : {deleted_interventions}")

        # Supprimer les pannes qui ne sont pas RESOLUE
        deleted_pannes = db.query(Panne).filter(Panne.statut != StatutPanneEnum.RESOLUE).delete(synchronize_session=False)
        print(f"  - Pannes non-résolues supprimées : {deleted_pannes}")
        
        db.commit()

        # 3. Compter les interventions terminées restantes
        current_completed = db.query(Intervention).filter(Intervention.statut == StatutInterventionEnum.TERMINEE).count()
        print(f"\nInterventions terminées actuelles : {current_completed}")
        
        target = 1000
        to_create = target - current_completed
        
        if to_create <= 0:
            print(f"Il y a déjà {current_completed} interventions terminées (cible : {target}). Aucun nouvel enregistrement requis.")
        else:
            print(f"Création de {to_create} interventions terminées et pannes résolues...")
            
            # Insérer par lot pour les performances
            batch_size = 100
            for i in range(to_create):
                # Sélectionner des entités aléatoirement
                machine = random.choice(machines)
                tech = random.choice(techniciens)
                superviseur = random.choice(superviseurs)
                type_panne = random.choice(types_panne)
                
                # Dates cohérentes
                date_decl = fake.date_time_between(start_date="-6M", end_date="now")
                date_debut = date_decl + timedelta(minutes=random.randint(5, 60))
                date_accept = date_debut + timedelta(minutes=random.randint(2, 15))
                date_scan = date_accept + timedelta(minutes=random.randint(5, 30))
                date_fin = date_scan + timedelta(minutes=random.randint(15, 240))
                
                # Créer la Panne
                panne = Panne(
                    id_machine=machine.id_machine,
                    id_type_panne=type_panne.id_type_panne,
                    id_superviseur=superviseur.id_superviseur,
                    priorite=random.randint(1, 5),
                    gravite=random.choice(list(GraviteEnum)),
                    statut=StatutPanneEnum.RESOLUE,
                    date_declaration=date_decl
                )
                db.add(panne)
                db.flush() # Pour avoir l'id_panne
                
                # Créer l'Intervention
                inter = Intervention(
                    id_panne=panne.id_panne,
                    id_technicien=tech.id_technicien,
                    date_debut=date_debut,
                    date_acceptation=date_accept,
                    date_scan_qr=date_scan,
                    date_fin=date_fin,
                    statut=StatutInterventionEnum.TERMINEE,
                    type_affectation=random.choice(list(TypeAffectationEnum))
                )
                db.add(inter)
                db.flush() # Pour avoir l'id_intervention
                
                # Créer le RapportPanne
                rapport = RapportPanne(
                    id_intervention=inter.id_intervention,
                    description_panne=fake.text(max_nb_chars=150),
                    travaux_effectues=fake.text(max_nb_chars=150),
                    type_travail=random.choice(["MCP", "MNP", "AUT"]),
                    temps_arret=int((date_fin - date_decl).total_seconds() / 60),
                    causes=fake.sentence(),
                    solutions=fake.sentence(),
                    etat_final="Opérationnel",
                    date_rapport=date_fin
                )
                db.add(rapport)
                
                # Créer une DemandeRechange (50% de chance)
                if pieces and random.random() > 0.5:
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
                
                # Commit par lot
                if (i + 1) % batch_size == 0:
                    db.commit()
                    print(f"  - Progress : {i + 1}/{to_create} insérés...")
            
            db.commit()
            print(f"Insertion complétée. Total inséré : {to_create}.")

        # 4. Recalculer l'HistoriquePanne et les statistiques des techniciens
        print("\nMise à jour de l'HistoriquePanne pour toutes les machines...")
        # Supprimer tout l'historique actuel pour le reconstruire proprement
        db.query(HistoriquePanne).delete()
        db.commit()
        
        # Reconstruire par machine
        for machine in machines:
            pannes_machine = db.query(Panne).filter_by(id_machine=machine.id_machine).all()
            if pannes_machine:
                last_panne = max([p.date_declaration for p in pannes_machine])
                hp = HistoriquePanne(
                    id_panne=random.choice(pannes_machine).id_panne,
                    id_type_panne=random.choice(pannes_machine).id_type_panne,
                    id_machine=machine.id_machine,
                    frequence_panne=len(pannes_machine),
                    dernie_panne=last_panne.date()
                )
                db.add(hp)
        db.commit()
        print("HistoriquePanne mis à jour.")

        print("\nMise à jour de StatistiqueTech pour tous les techniciens...")
        for tech in techniciens:
            st = db.query(StatistiqueTech).filter_by(id_technicien=tech.id_technicien).first()
            inters = db.query(Intervention).filter_by(id_technicien=tech.id_technicien, statut=StatutInterventionEnum.TERMINEE).all()
            
            # Temps moyen et taux de réussite factices
            temps_moyen = 0
            if inters:
                temps_totaux = []
                for inter in inters:
                    if inter.date_fin and inter.date_scan_qr:
                        temps_totaux.append((inter.date_fin - inter.date_scan_qr).total_seconds() / 60)
                temps_moyen = sum(temps_totaux) / len(temps_totaux) if temps_totaux else random.uniform(60, 240)
            
            if not st:
                st = StatistiqueTech(
                    id_technicien=tech.id_technicien,
                    nombreintervention=len(inters),
                    temps_moyen_intervention=temps_moyen,
                    taux_reussite=random.uniform(90, 100) if inters else 0
                )
                db.add(st)
            else:
                st.nombreintervention = len(inters)
                st.temps_moyen_intervention = temps_moyen
                st.taux_reussite = random.uniform(90, 100) if inters else 0
        db.commit()
        print("Statistiques techniciens mises à jour.")
        
        print("\nVérification finale :")
        pannes_count = db.query(Panne).count()
        inters_count = db.query(Intervention).count()
        resolved_pannes = db.query(Panne).filter(Panne.statut == StatutPanneEnum.RESOLUE).count()
        completed_inters = db.query(Intervention).filter(Intervention.statut == StatutInterventionEnum.TERMINEE).count()
        
        print(f"  - Nombre total de pannes : {pannes_count} (Résolues : {resolved_pannes})")
        print(f"  - Nombre total d'interventions : {inters_count} (Terminées : {completed_inters})")
        print("\nSuccès !")

    except Exception as e:
        print(f"Erreur lors du traitement : {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    main()
