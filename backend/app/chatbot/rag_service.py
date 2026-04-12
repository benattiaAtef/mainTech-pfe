"""
RAG Service — Retrieval Augmented Generation
============================================
Gère le stockage vectoriel (ChromaDB) et la récupération des
documents pertinents pour enrichir les réponses de TECHBOT.

Sources de données indexées :
  1. Documents textuels dans backend/app/data/knowledge/
  2. Historique des pannes et interventions (base de données SQL)
"""

import os
import logging
from pathlib import Path
from typing import Optional, TYPE_CHECKING, List

import chromadb # type: ignore
from chromadb.config import Settings # type: ignore

if TYPE_CHECKING:
    from sentence_transformers import SentenceTransformer # type: ignore
# L'import de SentenceTransformer est déplacé dans _get_embedder pour un chargement paresseux

logger = logging.getLogger(__name__)

# ─── Configuration ────────────────────────────────────────────────────────────
# Chemin vers le dossier de la base vectorielle persistante (dans 'app/data/')
CHROMA_DIR = Path(__file__).parent.parent / "data" / "chroma_db"
KNOWLEDGE_DIR = Path(__file__).parent.parent / "data" / "knowledge"

COLLECTION_NAME = "techbot_knowledge"

# Modèle d'embedding multilingue léger (fonctionne en français et anglais)
EMBEDDING_MODEL = "paraphrase-multilingual-MiniLM-L12-v2"

# Nombre de chunks pertinents à récupérer par requête
TOP_K = 4

# ─── Singleton instances ───────────────────────────────────────────────────────
_chroma_client: Optional[chromadb.PersistentClient] = None
_collection = None
# Typing as string to avoid circular or early import issues
_embedder: Optional['SentenceTransformer'] = None


def _get_embedder():
    """Charge le modèle d'embedding (singleton)."""
    global _embedder
    if _embedder is None:
        print("🔄 [RAG] Préparation du moteur d'IA... (Patientez 10-20s)")
        from sentence_transformers import SentenceTransformer # type: ignore
        _embedder = SentenceTransformer(EMBEDDING_MODEL)
        print("✅ [RAG] Moteur d'IA prêt.")
    return _embedder


def _get_collection():
    """Initialise et retourne la collection ChromaDB (singleton)."""
    global _chroma_client, _collection
    if _collection is None:
        CHROMA_DIR.mkdir(parents=True, exist_ok=True)
        _chroma_client = chromadb.PersistentClient(
            path=str(CHROMA_DIR),
            settings=Settings(anonymized_telemetry=False), # type: ignore
        )
        _collection = _chroma_client.get_or_create_collection(
            name=COLLECTION_NAME,
            metadata={"hnsw:space": "cosine"},
        )
        print(f"📦 [RAG] Collection ChromaDB prête ({_collection.count()} passages indexés).")
    return _collection


def add_documents(
    texts: List[str], 
    ids: List[str], 
    metadatas: Optional[List[dict]] = None
):
    """
    Ajoute (ou met à jour) des documents dans la base vectorielle.

    Args:
        texts    : Liste de textes à indexer
        ids      : Identifiants uniques pour chaque document
        metadatas: Métadonnées optionnelles (source, type, etc.)
    """
    if not texts:
        return

    embedder = _get_embedder()
    collection = _get_collection()

    embeddings = embedder.encode(texts, show_progress_bar=False).tolist()

    collection.upsert(
        documents=texts,
        embeddings=embeddings,
        ids=ids,
        metadatas=metadatas or [{}] * len(texts),
    )
    # logger.info(f"✅ {len(texts)} documents indexés dans ChromaDB.")


def retrieve_context(query: str, top_k: int = TOP_K) -> str:
    """
    Recherche les passages les plus pertinents pour une question donnée.

    Args:
        query : La question du technicien
        top_k : Nombre de résultats à retourner

    Returns:
        Un bloc de texte formaté avec les passages retrouvés,
        ou une chaîne vide si la base est vide.
    """
    collection = _get_collection()

    if collection.count() == 0:
        return ""

    embedder = _get_embedder()
    query_embedding = embedder.encode([query], show_progress_bar=False).tolist()

    results = collection.query(
        query_embeddings=query_embedding,
        n_results=min(top_k, collection.count()),
        include=["documents", "metadatas", "distances"],
    )

    documents = results.get("documents", [[]])[0]
    metadatas = results.get("metadatas", [[]])[0]
    distances = results.get("distances", [[]])[0]

    if not documents:
        return ""

    # Ne garder que les résultats suffisamment pertinents (distance cosine < 0.7)
    relevant = [
        (doc, meta, dist)
        for doc, meta, dist in zip(documents, metadatas, distances)
        if dist < 0.7
    ]

    if not relevant:
        return ""

    # Formater le contexte récupéré
    context_parts = ["=== INFORMATIONS TECHNIQUES PERTINENTES ==="]
    for i, (doc, meta, dist) in enumerate(relevant, 1):
        source = meta.get("source", "Base de connaissances")
        context_parts.append(f"\n[Source {i} — {source}]\n{doc}")

    context_parts.append("\n===========================================")
    return "\n".join(context_parts)


def get_collection_stats() -> dict:
    """Retourne des statistiques sur la base vectorielle."""
    try:
        collection = _get_collection()
        return {"total_documents": collection.count(), "status": "ok"}
    except Exception as e:
        return {"total_documents": 0, "status": f"erreur: {e}"}
