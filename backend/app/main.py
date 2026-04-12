import asyncio
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI # type: ignore
from fastapi.middleware.cors import CORSMiddleware # type: ignore

logger = logging.getLogger(__name__)

from app.core.database import engine, Base # type: ignore
from app.models import users, competence, machine, panne, intervention, autorisation, magasin # type: ignore
from app.router import admin_route, auth_route, competence_route, groupes_route, historique_panne_route, intervention_route, machine_route, panne_route, technicien_route, type_panne_route, user_route, dashboard_route, magasin_route, chat_route # type: ignore
from app.chatbot import router as chatbot_route # type: ignore

# Créer toutes les tables
Base.metadata.create_all(bind=engine)
#print("✅ Tables créées!")










@asynccontextmanager
async def lifespan(app: FastAPI):
    """Auto-indexation RAG au démarrage du serveur (non-bloquante)."""
    async def run_indexing():
        try:
            from app.chatbot.document_loader import index_all_sources # type: ignore
            from app.core.database import SessionLocal # type: ignore
            
            # Petit délai pour laisser uvicorn afficher le message de démarrage
            await asyncio.sleep(2)
            
            print("\n🚀 [RAG] Initialisation de la base de connaissances...")
            db = SessionLocal()
            loop = asyncio.get_event_loop()
            await loop.run_in_executor(None, index_all_sources, db)
            db.close()
            print("✅ [RAG] Indexation terminée. Chatbot prêt à l'emploi.\n")
        except Exception as e:
            print(f"⚠️ [RAG] Indexation échouée : {e}")

    # On lance l'indexation sans l'attendre (background)
    asyncio.create_task(run_indexing())
    
    yield  # L'application démarre ici immédiatement

app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Autoriser toutes les origines pour le développement
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
app.include_router(chatbot_route)
@app.get("/")
def read_root():
    return {"Hello": "World"}