"""
Document Loader — Indexation des sources de connaissances
===========================================================
Ce module indexe toutes les sources de données dans ChromaDB :

  1. Fichiers textuels (.txt, .md) dans app/data/knowledge/
  2. Fichiers PDF (.pdf) dans app/data/knowledge/
  3. Historique des pannes + interventions (base PostgreSQL)

Appelez `index_all_sources(db)` au démarrage ou via l'endpoint /chatbot/reindex.
"""

import logging
import re
from pathlib import Path
from typing import Optional

from sqlalchemy.orm import Session # type: ignore

from app.chatbot.rag_service import add_documents, get_collection_stats # type: ignore

logger = logging.getLogger(__name__)

# Chemin vers les fichiers de connaissance (dans 'app/data/knowledge')
KNOWLEDGE_DIR = Path(__file__).parent.parent / "data" / "knowledge" # backend/app/data/knowledge
CHUNK_SIZE = 500       # Nombre de mots par chunk
CHUNK_OVERLAP = 50     # Mots partagés entre chunks consécutifs


# ─── Utilitaire de découpage en chunks ────────────────────────────────────────

def _chunk_text(text: str, chunk_size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP) -> list[str]:
    """Découpe un texte en chunks de taille fixe avec chevauchement."""
    words = text.split()
    chunks = []
    start = 0
    while start < len(words):
        end = min(start + chunk_size, len(words))
        chunk = " ".join(words[start:end]) # type: ignore
        if chunk.strip():
            chunks.append(chunk)
        start = start + (chunk_size - overlap) # type: ignore
    return chunks


# ─── Chargement des fichiers texte et Markdown ────────────────────────────────

def _index_text_files() -> int:
    """Indexe tous les fichiers .txt et .md dans le dossier knowledge."""
    if not KNOWLEDGE_DIR.exists():
        KNOWLEDGE_DIR.mkdir(parents=True, exist_ok=True)
        return 0

    total = 0
    for file_path in KNOWLEDGE_DIR.rglob("*"):
        if file_path.suffix.lower().find(".txt") == -1 and file_path.suffix.lower().find(".md") == -1:
            continue
        if file_path.name == "README.md":
            continue  # Ignorer le README

        try:
            content = file_path.read_text(encoding="utf-8", errors="ignore")
            chunks = _chunk_text(content)
            if not chunks:
                continue

            texts, ids, metas = [], [], []
            for i, chunk in enumerate(chunks):
                doc_id = f"file_{file_path.stem}_{i}"
                texts.append(chunk)
                ids.append(doc_id)
                metas.append({"source": file_path.name, "type": "document"})

            add_documents(texts, ids, metas)
            total = total + len(chunks) # type: ignore
        except Exception as e:
            logger.error(f"  ❌ Erreur sur {file_path.name}: {e}")

    return total


# ─── Chargement des fichiers PDF ──────────────────────────────────────────────

def _index_pdf_files() -> int:
    """Indexe tous les fichiers PDF dans le dossier knowledge."""
    if not KNOWLEDGE_DIR.exists():
        return 0

    total = 0
    for file_path in KNOWLEDGE_DIR.rglob("*.pdf"):
        try:
            import pypdf # type: ignore

            reader = pypdf.PdfReader(str(file_path))
            full_text = ""
            for page in reader.pages:
                full_text += (page.extract_text() or "") + "\n"

            # Nettoyer le texte PDF (souvent bruité)
            full_text = re.sub(r"\s+", " ", full_text).strip()
            chunks = _chunk_text(full_text)

            if not chunks:
                logger.warning(f"  ⚠️  {file_path.name} : aucun texte extrait.")
                continue

            texts, ids, metas = [], [], []
            for i, chunk in enumerate(chunks):
                doc_id = f"pdf_{file_path.stem}_{i}"
                texts.append(chunk)
                ids.append(doc_id)
                metas.append({
                    "source": file_path.name,
                    "type": "pdf",
                    "pages": len(reader.pages),
                })

            add_documents(texts, ids, metas)
            total = total + len(chunks) # type: ignore
            print(f"    📖 Indexation PDF : {file_path.name} ({len(chunks)} fragments)")
        except ImportError:
            logger.warning("  ⚠️  pypdf non installé. Pour indexer les PDF : pip install pypdf")
            break
        except Exception as e:
            logger.error(f"  ❌ Erreur PDF {file_path.name}: {e}")

    return total


# ─── Chargement depuis la base de données PostgreSQL ─────────────────────────

def _index_database_history(db: Optional[Session]) -> int:
    """
    Indexe l'historique des pannes et interventions depuis la base de données.
    Crée des fiches de connaissances au format :
    'Machine X — panne Y — symptômes — solution appliquée'
    """
    if db is None:
        return 0

    total = 0
    try:
        # Import des modèles ici pour éviter les imports circulaires
        from app.models.intervention import Intervention # type: ignore
        from app.models.panne import Panne # type: ignore

        # Récupérer les interventions terminées avec leurs pannes
        from app.models.enums import StatutInterventionEnum
        interventions = (
            db.query(Intervention)
            .filter(Intervention.statut == StatutInterventionEnum.TERMINEE)
            .limit(500)  # Limiter pour ne pas surcharger
            .all()
        )

        texts, ids, metas = [], [], []

        for inv in interventions:
            try:
                panne = inv.panne if hasattr(inv, "panne") else None
                machine_nom = "Machine inconnue"
                type_panne = "Panne non spécifiée"
                localisation = ""

                if panne:
                    if hasattr(panne, "machine") and panne.machine:
                        machine_nom = panne.machine.nom or machine_nom
                        localisation = panne.machine.localisation or ""
                    if hasattr(panne, "type_panne") and panne.type_panne:
                        type_panne = panne.type_panne.nom_panne or type_panne

                # Construire la fiche de connaissance
                fiche_parts = [
                    f"Machine : {machine_nom}",
                    f"Type de panne : {type_panne}",
                ]
                if localisation:
                    fiche_parts.append(f"Localisation : {localisation}")

                # Ajouter le rapport si disponible
                rapport = getattr(inv, "rapport", None)
                if rapport:
                    # Utiliser les champs réels du modèle RapportPanne
                    if hasattr(rapport, "description_panne") and rapport.description_panne:
                        fiche_parts.append(f"Problème constaté : {rapport.description_panne}")
                    if hasattr(rapport, "causes") and rapport.causes:
                        fiche_parts.append(f"Cause identifiée : {rapport.causes}")
                    if hasattr(rapport, "solutions") and rapport.solutions:
                        fiche_parts.append(f"Solution appliquée : {rapport.solutions}")
                    if hasattr(rapport, "travaux_effectues") and rapport.travaux_effectues:
                        fiche_parts.append(f"Travaux réalisés : {rapport.travaux_effectues}")
                    if hasattr(rapport, "pieces_rechange") and rapport.pieces_rechange:
                        fiche_parts.append(f"Pièces utilisées : {rapport.pieces_rechange}")

                fiche = "\n".join(fiche_parts)
                doc_id = f"db_intervention_{inv.id_intervention}"
                texts.append(fiche)
                ids.append(doc_id)
                metas.append({
                    "source": f"Intervention #{inv.id_intervention} — {machine_nom}",
                    "type": "historique_bdd",
                    "machine": machine_nom,
                })
            except Exception as e:
                logger.debug(f"Erreur sur intervention {inv.id_intervention}: {e}")
                continue

        if texts:
            print(f"    🗄️  Indexation BDD : {len(texts)} interventions historiques...")
            add_documents(texts, ids, metas)
            total = len(texts)

    except Exception as e:
        logger.error(f"  ❌ Erreur indexation BDD: {e}")

    return total


# ─── Point d'entrée principal ─────────────────────────────────────────────────

def index_all_sources(db: Optional[Session] = None) -> dict:
    """
    Indexe toutes les sources : fichiers (txt, md, pdf) + historique BDD.
    Appeler au démarrage de l'application ou via /chatbot/reindex.

    Returns:
        Dictionnaire avec le résultat de chaque source
    """
    txt_count = _index_text_files()
    pdf_count = _index_pdf_files()
    db_count = _index_database_history(db)
    
    print("\n💡 NOTE : Les messages 'BertModel' et 'UNEXPECTED' ci-dessus sont NORMAUX.")
    print("Ils indiquent que le modèle d'IA a été chargé avec succès.\n")
    
    stats = get_collection_stats() # type: ignore

    result = {
        "fichiers_txt_md": txt_count,
        "fichiers_pdf": pdf_count,
        "historique_bdd": db_count,
        "total_vecteurs": stats["total_documents"], # type: ignore
        "statut": "ok",
    }

    logger.info(f"✅ Indexation terminée : {result}")
    return result
