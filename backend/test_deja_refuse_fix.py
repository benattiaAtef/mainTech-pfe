"""
Test de vérification : la sous-requête deja_refuse fonctionne-t-elle correctement ?
Ce script simule exactement ce que fait assigner_panne_en_attente_si_possible pour un tech refusé.
"""
import sys
sys.path.insert(0, ".")

from app.core.database import SessionLocal
from app.models.autorisation import AutorisationExceptionnelle
from app.models.intervention import Intervention
from app.models.enums import StatutAutorisationEnum
from app.models.users import Technicien
from app.models.panne import Panne
from app.models.enums import StatutPanneEnum

db = SessionLocal()

print("=" * 60)
print("TEST: Vérification du check deja_refuse (sous-requête)")
print("=" * 60)

# Prendre la Panne 1621 avec Tech 16 (cas du bug)
ID_PANNE = 1621
ID_TECH = 16

# Simuler exactement la sous-requête utilisée dans assigner_panne_en_attente_si_possible
inter_ids = db.query(Intervention.id_intervention).filter(
    Intervention.id_panne == ID_PANNE,
    Intervention.id_technicien == ID_TECH
).subquery()

deja_refuse = db.query(AutorisationExceptionnelle).filter(
    AutorisationExceptionnelle.id_intervention.in_(inter_ids),
    AutorisationExceptionnelle.statut == StatutAutorisationEnum.REFUSEE
).first()

print(f"\nPanne {ID_PANNE} | Tech {ID_TECH}")
print(f"deja_refuse = {deja_refuse is not None}")
if deja_refuse:
    print(f"  → Auth ID: {deja_refuse.id_autorisation} | Statut: {deja_refuse.statut}")
    print("  ✅ CORRECT: ce technicien sera bloqué et ne recevra pas la panne")
else:
    print("  ❌ PROBLÈME: aucune autorisation refusée trouvée pour ce technicien/panne")

# Vérifier toutes les pannes EN_ATTENTE actuellement
print("\n" + "=" * 60)
print("Pannes EN_ATTENTE actuellement:")
pannes = db.query(Panne).filter(Panne.statut == StatutPanneEnum.EN_ATTENTE).all()
for p in pannes:
    # Nombre d'autorisations refusées pour cette panne
    count_refuses = db.query(AutorisationExceptionnelle).filter(
        AutorisationExceptionnelle.id_intervention.in_(
            db.query(Intervention.id_intervention).filter(Intervention.id_panne == p.id_panne)
        ),
        AutorisationExceptionnelle.statut == StatutAutorisationEnum.REFUSEE
    ).count()
    print(f"  Panne {p.id_panne} | Refus: {count_refuses}")

db.close()
print("\nTest terminé.")
