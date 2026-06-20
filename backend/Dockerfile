# Utiliser une image Python légère
FROM python:3.11-slim

# Éviter la génération de fichiers .pyc et afficher les logs directement
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Dossiers de cache dans /tmp pour Hugging Face
ENV HF_HOME=/tmp/huggingface
ENV TRANSFORMERS_CACHE=/tmp/huggingface/transformers
ENV SENTENCE_TRANSFORMERS_HOME=/tmp/huggingface/sentence_transformers
ENV TORCH_HOME=/tmp/torch

# Définir le répertoire de travail
WORKDIR /app

# Installer les dépendances système nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    gcc \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copier les dépendances Python
COPY requirements.txt .

# Installer pip
RUN pip install --no-cache-dir --upgrade pip

# Installer PyTorch CPU uniquement pour éviter les packages CUDA très lourds
RUN pip install --no-cache-dir torch --index-url https://download.pytorch.org/whl/cpu

# Installer le reste des dépendances
RUN pip install --no-cache-dir --default-timeout=100 -r requirements.txt

# Copier le code source
COPY . .

# Hugging Face Spaces utilise le port défini dans README.md app_port
EXPOSE 7860

# Lancer FastAPI sur le port 7860
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]