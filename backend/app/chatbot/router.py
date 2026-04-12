from fastapi import APIRouter, Depends, HTTPException, BackgroundTasks # type: ignore
from sqlalchemy.orm import Session # type: ignore

from app.core.database import get_db # type: ignore
from app.core.security import get_current_user # type: ignore
from app.chatbot.schema import ChatbotRequest, ChatbotResponse # type: ignore
from app.chatbot.service import get_chatbot_response # type: ignore
from app.chatbot.document_loader import index_all_sources # type: ignore
from app.chatbot.rag_service import get_collection_stats # type: ignore

router_chatbot = APIRouter(
    prefix="/chatbot",
    tags=["Chatbot IA"]
)


@router_chatbot.post("/ask", response_model=ChatbotResponse)
def ask_chatbot(
    request: ChatbotRequest,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Pose une question à TECHBOT (RAG activé).
    Le chatbot cherche d'abord dans la base vectorielle (ChromaDB)
    avant d'appeler Gemini pour une réponse enrichie.
    """
    if not request.message or not request.message.strip():
        raise HTTPException(status_code=400, detail="Le message ne peut pas être vide.")

    reply = get_chatbot_response(
        user_message=request.message.strip(),
        machine_context=request.machine_context,
        use_rag=True,
    )

    return ChatbotResponse(reply=reply)


@router_chatbot.post("/reindex")
def reindex_knowledge(
    background_tasks: BackgroundTasks,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Déclenche la ré-indexation de toutes les sources dans ChromaDB :
    - Fichiers TXT / Markdown / PDF du dossier data/knowledge/
    - Historique des pannes et interventions (base PostgreSQL)

    L'indexation s'exécute en arrière-plan.
    """
    def run_indexing():
        index_all_sources(db)

    background_tasks.add_task(run_indexing)

    return {
        "message": "✅ Indexation RAG lancée en arrière-plan.",
        "info": "Cela peut prendre quelques minutes selon la quantité de données."
    }


@router_chatbot.get("/stats")
def get_rag_stats(
    current_user=Depends(get_current_user),
):
    """Retourne les statistiques de la base vectorielle ChromaDB."""
    stats = get_collection_stats()
    return {
        "base_vectorielle": stats,
        "description": "Nombre de chunks de documents indexés dans ChromaDB."
    }
