import asyncio
import logging
import os
from contextlib import asynccontextmanager

from fastapi import FastAPI  # type: ignore
from fastapi.middleware.cors import CORSMiddleware  # type: ignore

from app.core.database import engine, Base  # type: ignore
from app.models import users, competence, machine, panne, intervention, autorisation, magasin  # type: ignore

from app.router import (
    admin_route,
    auth_route,
    competence_route,
    groupes_route,
    historique_panne_route,
    intervention_route,
    machine_route,
    panne_route,
    technicien_route,
    type_panne_route,
    user_route,
    dashboard_route,
    magasin_route,
    chat_route,
)  # type: ignore


# =========================================================
# Configuration générale
# =========================================================

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

DISABLE_RAG = os.getenv("DISABLE_RAG", "0") == "1"


# =========================================================
# Création des tables
# =========================================================

Base.metadata.create_all(bind=engine)


# =========================================================
# Seeding de la base de données
# =========================================================

def seed_db():
    from app.core.database import SessionLocal
    from app.models.users import Utilisateur, Administrateur
    from app.models.enums import RoleEnum, StatutPresenceEnum
    from app.core.security import get_password_hash

    db = SessionLocal()

    try:
        admin_email = "atef0006@gmail.com"

        admin = db.query(Utilisateur).filter(
            Utilisateur.email == admin_email
        ).first()

        if not admin:
            print(f"🌱 Seeding database: Creating admin {admin_email}...")

            new_admin = Utilisateur(
                nom="Atef",
                prenom="Admin",
                email=admin_email,
                mot_de_passe=get_password_hash("mdp123456"),
                role=RoleEnum.ADMINISTRATEUR,
                statut_presence=StatutPresenceEnum.EN_TRAVAIL,
            )

            db.add(new_admin)
            db.commit()
            db.refresh(new_admin)

            admin_record = Administrateur(
                id_utilisateur=new_admin.id_utilisateur,
                niveau_acces="super_admin",
            )

            db.add(admin_record)
            db.commit()

            print("✅ Database seeded successfully!")

        else:
            print("ℹ️ Database already seeded.")

    except Exception as e:
        print(f"❌ Error during seeding: {e}")
        db.rollback()

    finally:
        db.close()


# =========================================================
# Lifespan FastAPI
# =========================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Initialisation au démarrage du serveur.

    En production Render, il est conseillé de désactiver le RAG
    avec la variable d'environnement DISABLE_RAG=1 afin d'éviter
    les problèmes de mémoire et les redémarrages fréquents.
    """

    # Initialisation des données nécessaires
    seed_db()

    async def run_indexing():
        try:
            from app.chatbot.document_loader import index_all_sources  # type: ignore
            from app.core.database import SessionLocal  # type: ignore

            await asyncio.sleep(2)

            print("\n🚀 [RAG] Initialisation de la base de connaissances...")

            db = SessionLocal()

            try:
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, index_all_sources, db)
                print("✅ [RAG] Indexation terminée. Chatbot prêt à l'emploi.\n")

            finally:
                db.close()

        except Exception as e:
            print(f"⚠️ [RAG] Indexation échouée : {e}")

    if DISABLE_RAG:
        print("ℹ️ [RAG] Désactivé en production avec DISABLE_RAG=1.")
    else:
        print("🔄 [RAG] Préparation du moteur d'IA en arrière-plan...")
        asyncio.create_task(run_indexing())

    yield


# =========================================================
# Création de l'application FastAPI
# =========================================================

app = FastAPI(
    title="MainTech API",
    description="API backend de l'application MainTech",
    version="1.0.0",
    lifespan=lifespan,
)


# =========================================================
# Configuration CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# Routes principales
# =========================================================

app.include_router(auth_route.router)
app.include_router(user_route.router_users)
app.include_router(groupes_route.router_groupes)
app.include_router(technicien_route.router_techniciens)
app.include_router(machine_route.router_machines)
app.include_router(competence_route.router_competences)
app.include_router(panne_route.router_panne)
app.include_router(admin_route.router_admin)
app.include_router(intervention_route.router_interventions)
app.include_router(historique_panne_route.router_historique)
app.include_router(type_panne_route.router_type_panne)
app.include_router(dashboard_route.router_dashboard)
app.include_router(magasin_route.router_magasin)
app.include_router(chat_route.router_chat)


# =========================================================
# Route Chatbot / RAG
# =========================================================

if not DISABLE_RAG:
    try:
        from app.chatbot import router as chatbot_route  # type: ignore

        app.include_router(chatbot_route)
        print("✅ [RAG] Router chatbot activé.")

    except Exception as e:
        print(f"⚠️ [RAG] Impossible de charger le router chatbot : {e}")

else:
    print("ℹ️ [RAG] Router chatbot désactivé sur Render.")


# =========================================================
# Routes de test et health check
# =========================================================

@app.get("/")
def read_root():
    return {
        "message": "MainTech API is running",
        "status": "ok",
    }


@app.head("/")
def head_root():
    return {}


@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "MainTech API",
    }