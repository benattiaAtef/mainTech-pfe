"""
Configuration de la base de données SQLAlchemy
"""
from multiprocessing.util import DEBUG
import os
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from typing import Optional

# Créer le moteur de base de données
# En production/Docker, on utilise l'URL fournie par l'environnement
# Par défaut, on garde l'URL locale pour ne pas casser le dev actuel
SQLALCHEMY_DATABASE_URL = os.getenv(
    "DATABASE_URL", 
    "postgresql://neondb_owner:npg_NOsRW1E0hvdg@ep-damp-paper-ap4etceh-pooler.c-7.us-east-1.aws.neon.tech/neondb?sslmode=require"
)


engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"options": "-csearch_path=public"},
    pool_pre_ping=True,
)


# Créer la session locale
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine
)

# Base pour les modèles
Base = declarative_base()


# Dépendance pour obtenir une session DB
def get_db():
    """
    Générateur de session de base de données
    À utiliser comme dépendance FastAPI
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()