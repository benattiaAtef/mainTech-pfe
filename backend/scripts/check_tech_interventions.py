import sys
import os
import datetime

sys.path.append(r"c:\Users\atef0\Desktop\mainTech\backend")

from app.core.database import SessionLocal
from app.models.intervention import Intervention

def main():
    db = SessionLocal()
    try:
        for tech_id in [14, 15]:
            print(f"--- Interventions for Tech ID {tech_id} ---")
            inters = db.query(Intervention).filter(Intervention.id_technicien == tech_id).all()
            print(f"Total interventions: {len(inters)}")
            
            # Print detail of first 5
            for i in inters[:5]:
                print(f"  ID: {i.id_intervention}, Statut: {i.statut}, DateDebut: {i.date_debut}, DateScan: {i.date_scan_qr}, DateFin: {i.date_fin}, Duree: {i.duree}")
                
            # Check if there are any ongoing interventions
            ongoing = db.query(Intervention).filter(Intervention.id_technicien == tech_id, Intervention.statut == "en_cours").all()
            print(f"Ongoing: {len(ongoing)}")
            for i in ongoing:
                print(f"  Ongoing ID: {i.id_intervention}, DateScan: {i.date_scan_qr}")
                
            # Check if there are any interventions with huge duration
            for i in inters:
                if i.duree and i.duree > 1000:
                    print(f"  Long ID: {i.id_intervention}, Duree: {i.duree} min")
                    
    except Exception as e:
        print(f"Error: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    main()
