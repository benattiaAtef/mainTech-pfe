import os
import sys

sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.core.database import SessionLocal
from app.models.autorisation import AutorisationExceptionnelle
from app.models.intervention import Intervention

def main():
    db = SessionLocal()
    try:
        refus_list = db.query(AutorisationExceptionnelle).filter(
            AutorisationExceptionnelle.statut == "REFUSEE"
        ).all()
        
        print(f"Found {len(refus_list)} refused authorizations:")
        for r in refus_list:
            inter = r.intervention
            if inter:
                print(f"Auth ID: {r.id_autorisation} | Inter ID: {inter.id_intervention} | Panne ID: {inter.id_panne} | Tech ID: {inter.id_technicien}")
            else:
                print(f"Auth ID: {r.id_autorisation} has no associated intervention!")
                
    except Exception as e:
        print("Error:", e)
    finally:
        db.close()

if __name__ == "__main__":
    main()
