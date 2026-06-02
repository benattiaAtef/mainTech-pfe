import sys
import os

sys.path.append(r"c:\Users\atef0\Desktop\mainTech\backend")

from app.core.database import SessionLocal
from app.models.autorisation import StatistiqueTech
from app.models.users import Technicien

def main():
    db = SessionLocal()
    try:
        print("Checking StatistiqueTech...")
        stats = db.query(StatistiqueTech).all()
        for s in stats:
            print(f"Tech ID: {s.id_technicien}")
            print(f"  nombreintervention: {s.nombreintervention}")
            print(f"  temps_moyen_intervention: {s.temps_moyen_intervention}")
            print(f"  taux_reussite: {s.taux_reussite}")
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
