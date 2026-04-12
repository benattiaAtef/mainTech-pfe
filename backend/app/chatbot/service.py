"""
Chatbot Service — TECHBOT avec RAG (Version google-genai 1.0+)
============================================================
Pipeline complet :
  1. Retrieve : recherche sémantique dans ChromaDB (rag_service)
  2. Augment  : injection du contexte dans le prompt Gemini
  3. Generate : génération de la réponse avec le SDK google-genai
"""

import os
import logging
from typing import Optional
from google import genai # type: ignore
from dotenv import load_dotenv # type: ignore

from app.chatbot.rag_service import retrieve_context # type: ignore

load_dotenv()
logger = logging.getLogger(__name__)

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

# ─── Prompt Système ────────────────────────────────────────────────────────────
SYSTEM_PROMPT = """Tu es TECHBOT, un ingénieur expert en maintenance industrielle avec 20 ans d'expérience. 
Ton rôle est de fournir une assistance technique rigoureuse, précise et structurée aux techniciens sur le terrain.

### Directives de réponse :
1. **Ton & Langage** : Utilise un ton professionnel, exemplaire et technique. Adresse-toi au technicien en utilisant le "vous".
2. **Structure Obligatoire** : Organise TOUJOURS ta réponse avec les sections suivantes (EN MAJUSCULES) :
    - 🔍 ANALYSE DU PROBLEME : Résumé technique de la situation.
    - 🛠️ PROCEDURE DE RESOLUTION : Liste numérotée et détaillée des étapes à suivre.
    - ⚠️ CONSIGNES DE SECURITE : Rappel des EPI nécessaires et des procédures de consignation (LOTO).
    - 📦 PIECES ET OUTILS : Liste des éléments nécessaires à l'intervention.
3. **Utilisation du Contexte (RAG)** : Utilise prioritairement les informations fournies dans le "CONTEXTE TECHNIQUE" (issus des manuels constructeurs).
4. **Précision** : Si une information (couple de serrage, valeur électrique) est présente dans le contexte, cite-la précisément.
5. **Formatage (TRES IMPORTANT)** : N'UTILISE AUCUNE ETOILE (`*` ou `**`) dans ta réponse. Le système ne les affiche pas correctement. Pour faire des listes, utilise uniquement des tirets (`-`) ou des numéros (`1.`, `2.`). Pour mettre en évidence, utilise des MAJUSCULES.

**Sécurité d'abord** : Si une intervention présente un danger mortel ou nécessite une habilitation spécifique, mentionne-le en MAJUSCULES dès le début.
"""


def get_chatbot_response(
    user_message: str,
    machine_context: Optional[str] = None,
    use_rag: bool = True,
) -> str:
    """
    Génère une réponse augmentée par RAG via le nouveau SDK google-genai.
    Utilise gemini-2.5-flash (seul modèle fonctionnel sans erreur de quota/404).
    """
    if not GEMINI_API_KEY:
        return "❌ Erreur de configuration : clé API Gemini manquante dans .env"

    try:
        # ── RETRIEVAL (RAG) ────────────────────────────────────────────────
        rag_context = ""
        if use_rag:
            search_query = user_message
            if machine_context:
                search_query = f"{machine_context} — {user_message}"
            rag_context = retrieve_context(search_query)

        # ── CONSTRUCTION DU PROMPT ──────────────────────────────────────────
        # On injecte le SYSTEM_PROMPT au début du texte pour une compatibilité maximale
        # avec les différentes versions de l'API Gemini.
        prompt_parts = [
            f"INSTRUCTION SYSTÈME : {SYSTEM_PROMPT}",
            "\n---"
        ]
        if machine_context:
            prompt_parts.append(f"[Machine : {machine_context}]")
        if rag_context:
            prompt_parts.append(f"CONTEXTE TECHNIQUE (RAG) :\n{rag_context}")
        
        prompt_parts.append(f"\nQUESTION DU TECHNICIEN : {user_message}")
        final_prompt = "\n\n".join(prompt_parts)

        # ── GÉNÉRATION ──────────────────────────────────────────────────────
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        # Liste de modèles à essayer par ordre de préférence (selon disponibilité sur ce compte)
        models_to_try = [
            "gemini-flash-latest",
            "gemini-1.5-flash",
            "gemini-2.0-flash",
            "gemini-pro-latest"
        ]
        
        last_error = ""
        for model_name in models_to_try:
            try:
                response = client.models.generate_content(
                    model=model_name,
                    contents=final_prompt
                )
                if response and response.text:
                    return response.text
                continue
            except Exception as e:
                last_error = str(e)
                error_msg = str(last_error)
                # On réessaie pour les erreurs temporaires : Surcharge (503), Quota (429), Pas trouvé (404), Timeout (504)
                if any(err in error_msg for err in ["503", "429", "404", "504"]):
                    logger.warning(f"Modèle {model_name} indisponible ({error_msg}), essai du modèle suivant...")
                    continue
                else:
                    # Pour les autres erreurs fatales, on arrête
                    break

        # Si tous ont échoué
        if str(last_error).find("429") != -1: # type: ignore
            return (
                "❌ Quota Gemini épuisé (Erreur 429).\n\n"
                "Le modèle gemini-2.5-flash a été essayé mais semble être restreint.\n\n"
                "Solution : Reliez un compte de facturation (même gratuit) sur Google Cloud Console."
            )
        return f"❌ Erreur TECHBOT : {last_error}"

    except Exception as e:
        error_msg = str(e)
        logger.error(f"Erreur fatale chatbot: {error_msg}")
        return f"❌ Erreur du service IA : {error_msg}"
