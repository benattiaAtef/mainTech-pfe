import os
import sys

# Add backend directory to sys.path so we can import the models
sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.core.database import SessionLocal
from app.models.autorisation import AutorisationExceptionnelle
from app.models.intervention import Intervention
from app.models.enums import StatutAutorisationEnum

def main():
    db = SessionLocal()
    try:
        print("Database connection successful.")
        
        # Test the query
        print("Testing join query...")
        query = db.query(AutorisationExceptionnelle).join(Intervention)
        print("Join query constructed successfully.")
        
        # Print SQL
        print("Generated SQL:")
        print(query.statement)
        
        # Execute query
        results = query.limit(5).all()
        print(f"Query returned {len(results)} results.")
        for r in results:
            print(f"Autorisation ID: {r.id_autorisation}, Intervention ID: {r.id_intervention}, Statut: {r.statut}")
            
    except Exception as e:
        print("Error during execution:", e)
    finally:
        db.close()

if __name__ == "__main__":
    main()
