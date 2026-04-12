# core/security.py  — version mise à jour

from datetime import datetime, timedelta
from typing import Optional
import os

from jose import jwt, JWTError
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from app.core.database import get_db


SECRET_KEY = os.getenv("SECRET_KEY", "changez-moi-en-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 720 # 12 hours for development

payload = {
    "exp": datetime.utcnow() + timedelta(minutes=30),  # Date d'expiration du token
    "sub": "5",                                         # ID de l'utilisateur (subject)
    "role": "technicien"                                # Rôle de l'utilisateur
}

# On ne garde qu'une seule définition propre de pwd_context
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")
MAX_BCRYPT_LEN = 72  # bcrypt ne supporte que 72 bytes

def get_password_hash(password: str) -> str:
    if len(password) > MAX_BCRYPT_LEN:
        password = password[:MAX_BCRYPT_LEN]
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    if len(plain_password) > MAX_BCRYPT_LEN:
        plain_password = plain_password[:MAX_BCRYPT_LEN]
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(subject: str, role: str, expires_delta: Optional[timedelta] = None) -> str:
    expire = datetime.utcnow() + (expires_delta or timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES))
    payload = {"exp": expire, "sub": str(subject), "role": role}
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_token(token: str) -> Optional[dict]:
    """
    Retourne un dict {"sub": user_id, "role": role} ou None
    """
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = str(payload.get("sub"))
        role: str = str(payload.get("role"))
        if user_id is None or role is None:
            return None
        return {"sub": user_id, "role": role}
    except JWTError:
        return None


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db)
):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Impossible de valider les identifiants",
        headers={"WWW-Authenticate": "Bearer"},
    )

    data = decode_token(token)
    if data is None:
        raise credentials_exception

    from app.models.users import Utilisateur
    user = db.query(Utilisateur).filter(Utilisateur.id_utilisateur == int(data["sub"])).first()

    if user is None:
        raise credentials_exception

    return user


def get_current_active_user(current_user=Depends(get_current_user)):
    if hasattr(current_user, "is_active") and not current_user.is_active:
        raise HTTPException(status_code=400, detail="Utilisateur inactif")
    return current_user


from app.models.users import RoleEnum

def require_role(*allowed_roles: RoleEnum):
    def role_checker(current_user=Depends(get_current_user)):
        if current_user.role not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Accès refusé."
            )
        return current_user
    return role_checker