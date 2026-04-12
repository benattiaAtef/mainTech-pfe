# Dossier des Connaissances Techniques du Chatbot

Ce dossier contient les fichiers de connaissances utilisés par TECHBOT.

## Emplacement des données

Placez ici vos fichiers de documentation technique :

- `manuels/` → Manuels de réparation des machines (PDF, TXT)
- `procedures/` → Procédures standard de maintenance
- `codes_erreurs/` → Listes de codes d'erreur par machine

## Comment utiliser ces données

Pour l'instant, le chatbot utilise le modèle Gemini de manière généraliste.

Pour connecter vos propres données (RAG), modifiez la fonction `get_chatbot_response()`
dans `backend/app/utils/chatbot_service.py` pour lire et injecter le contenu
de ces fichiers dans le prompt avant d'appeler Gemini.
