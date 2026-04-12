from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.intervention import Intervention
from app.models.panne import Panne, HistoriquePanne, TypePanne
from app.models.autorisation import StatistiqueTech
from app.models.enums import StatutInterventionEnum, StatutPanneEnum
from datetime import date, datetime, timedelta

def update_tech_stats(db: Session, tech_id: int):
    """Met à jour les statistiques globales d'un technicien."""
    # Nombre d'interventions terminées
    interventions = db.query(Intervention).filter(
        Intervention.id_technicien == tech_id,
        Intervention.statut == StatutInterventionEnum.TERMINEE
    ).all()
    
    count = len(interventions)
    if count == 0:
        return

    # Temps moyen (basé sur la propriété duree du modèle)
    total_duree = 0
    valid_count = 0
    for i in interventions:
        d = i.duree
        if d is not None:
            total_duree += d
            valid_count += 1
    
    avg_time = (total_duree / valid_count) if valid_count > 0 else 0

    # Taux de réussite (pour l'instant on simule car on n'a pas de notion d'échec explicite)
    # On pourrait dire que toute intervention TERMINEE est un succès
    success_rate = 100.0

    stats = db.query(StatistiqueTech).filter(StatistiqueTech.id_technicien == tech_id).first()
    if not stats:
        stats = StatistiqueTech(id_technicien=tech_id)
        db.add(stats)
    
    stats.nombreintervention = count
    stats.temps_moyen_intervention = avg_time
    stats.taux_reussite = success_rate
    
    db.commit()

def archive_panne_history(db: Session, panne_id: int):
    """Archive une panne résolue dans l'historique."""
    panne = db.query(Panne).filter(Panne.id_panne == panne_id).first()
    if not panne or panne.statut != StatutPanneEnum.RESOLUE:
        return

    # Vérifier si une entrée existe déjà
    existing = db.query(HistoriquePanne).filter(HistoriquePanne.id_panne == panne_id).first()
    if existing:
        return

    # Calculer la fréquence (pour l'instant, nombre de pannes du même type sur cette machine sur les 30 derniers jours)
    # C'est une simplification
    count_last_month = db.query(Panne).filter(
        Panne.id_machine == panne.id_machine,
        Panne.id_type_panne == panne.id_type_panne,
        Panne.date_declaration >= datetime.utcnow() - timedelta(days=30)
    ).count()

    history = HistoriquePanne(
        id_panne=panne.id_panne,
        id_type_panne=panne.id_type_panne,
        id_machine=panne.id_machine,
        frequence_panne=float(count_last_month),
        dernie_panne=date.today()
    )
    
    db.add(history)
    db.commit()
