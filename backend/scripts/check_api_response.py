import sys
import os
import datetime

sys.path.append(r"c:\Users\atef0\Desktop\mainTech\backend")

from app.core.database import SessionLocal
from app.models.users import Technicien
from app.router.technicien_route import get_technician_stats

def main():
    db = SessionLocal()
    try:
        techs = db.query(Technicien).all()
        print(f"Current Date/Time: {datetime.datetime.utcnow()}")
        print(f"Date today used: {datetime.date.today()}")
        for tech in techs:
            count, minutes = get_technician_stats(db, tech)
            print(f"Tech ID: {tech.id_technicien} (Matricule: {tech.matricule})")
            print(f"  Count today: {count}")
            print(f"  Minutes today: {minutes}")
            
            # Let's count total interventions in DB for this tech
            from app.models.intervention import Intervention
            total_int = db.query(Intervention).filter(Intervention.id_technicien == tech.id_technicien).count()
            print(f"  Total interventions: {total_int}")
            
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
