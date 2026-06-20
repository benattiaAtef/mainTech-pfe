"""
Chatbot Service — TECHBOT avec RAG (Version Groq)
============================================================
Pipeline complet :
  1. Retrieve : recherche sémantique dans ChromaDB (rag_service)
  2. Augment  : injection du contexte dans le prompt
  3. Generate : génération de la réponse avec Groq (llama-3.3-70b-versatile)
"""

import os
import logging
from typing import Optional
from groq import Groq  # type: ignore
from dotenv import load_dotenv  # type: ignore

from app.chatbot.rag_service import retrieve_context  # type: ignore

load_dotenv()
logger = logging.getLogger(__name__)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")

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
    Génère une réponse augmentée par RAG via l'API Groq.
    Utilise le modèle llama-3.3-70b-versatile (gratuit et très rapide).
    """
    if not GROQ_API_KEY:
        return "❌ Erreur de configuration : clé API Groq manquante. Ajoutez GROQ_API_KEY dans les secrets Hugging Face."

    try:
        # ── RETRIEVAL (RAG) ────────────────────────────────────────────────
        rag_context = ""
        if use_rag:
            search_query = user_message
            if machine_context:
                search_query = f"{machine_context} — {user_message}"
            rag_context = retrieve_context(search_query)

        # ── CONSTRUCTION DU PROMPT UTILISATEUR ─────────────────────────────
        user_content_parts = []
        if machine_context:
            user_content_parts.append(f"[Machine concernée : {machine_context}]")
        if rag_context:
            user_content_parts.append(f"CONTEXTE TECHNIQUE (issu des manuels) :\n{rag_context}")
        user_content_parts.append(f"QUESTION DU TECHNICIEN : {user_message}")
        user_content = "\n\n".join(user_content_parts)

        # ── GÉNÉRATION VIA GROQ ─────────────────────────────────────────────
        client = Groq(api_key=GROQ_API_KEY)

        completion = client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": user_content},
            ],
            temperature=0.3,
            max_tokens=2048,
        )

        response_text = completion.choices[0].message.content
        if response_text:
            return response_text
        return "❌ Le modèle n'a pas retourné de réponse. Veuillez réessayer."

    except Exception as e:
        error_msg = str(e)
        logger.error(f"Erreur TECHBOT Groq: {error_msg}")

        if "401" in error_msg or "invalid_api_key" in error_msg.lower():
            return "❌ Clé API Groq invalide. Vérifiez votre clé sur https://console.groq.com/keys"
        if "429" in error_msg:
            return "❌ Quota Groq temporairement épuisé. Réessayez dans quelques secondes."
        if "503" in error_msg or "502" in error_msg:
            return "❌ Service Groq temporairement indisponible. Réessayez dans un instant."

        return f"❌ Erreur TECHBOT : {error_msg}"
