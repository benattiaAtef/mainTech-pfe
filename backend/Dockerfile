# Utiliser une image Python légère
FROM python:3.11-slim

# Éviter la génération de fichiers .pyc et activer le mode non-interactif
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Définir le répertoire de travail
WORKDIR /app

# Installer les dépendances système nécessaires (pour psycopg2 et autres)
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copier le fichier des dépendances
COPY requirements.txt .

# ÉTAPE D'OPTIMISATION CRITIQUE :
# Par défaut, sentence-transformers installe PyTorch (torch) avec support GPU/CUDA, ce qui télécharge un package énorme de ~2 Go.
# Comme le conteneur tourne sur CPU, on installe la version CPU de PyTorch en premier (~150 Mo, soit 10x plus léger et rapide).
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

# Installer le reste des dépendances Python
RUN pip install --no-cache-dir --default-timeout=100 -r requirements.txt

# Copier le reste du code source
COPY . .

# Exposer le port sur lequel l'app tourne
EXPOSE 8000

# Commande pour démarrer l'application
# On utilise 0.0.0.0 pour être accessible depuis l'extérieur du conteneur
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
