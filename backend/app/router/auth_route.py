


from datetime import timedelta
from tokenize import Token
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session

from datetime import timedelta
from fastapi import APIRouter, Depends, status, HTTPException
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session




from fastapi import APIRouter, Depends,status,HTTPException

from app.core.database import get_db
from app.core.security import ACCESS_TOKEN_EXPIRE_MINUTES, create_access_token, get_password_hash, verify_password
from app.models.users import Utilisateur
from app.models.enums import RoleEnum, StatutPresenceEnum
from app.shema.schemas_auth import LoginRequest, TokenResponse
from app.shema.user import UtilisateurCreate, UtilisateurResponse


router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UtilisateurResponse, status_code=status.HTTP_201_CREATED)
async def register(user_data: UtilisateurCreate, db: Session = Depends(get_db)):
    """Register a new user"""
    
    # Check if email already exists
    existing_user = db.query(Utilisateur).filter(Utilisateur.email == user_data.email).all()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Create new user
    new_user = Utilisateur(
        nom=user_data.nom,
        prenom=user_data.prenom,
        email=user_data.email,
        mot_de_passe=get_password_hash(user_data.mot_de_passe),
        role=user_data.role.value,
        statut_presence=StatutPresenceEnum.EN_TRAVAIL.value
    )
    
    db.add(new_user)
    print(f"DEBUG: Registering User - Role: {new_user.role}, Statut: {new_user.statut_presence}")
    db.commit()
    db.refresh(new_user)
    
    return new_user



ROLES_AUTORISES = [
    RoleEnum.ADMINISTRATEUR,
    RoleEnum.SUPERVISEUR,
    RoleEnum.CHEF_EQUIPE,
    RoleEnum.MAGASINIER,
    RoleEnum.TECHNICIEN,
]

@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    """
    Endpoint de connexion unique pour tous les rôles.
    Le système détecte automatiquement le rôle de l'utilisateur
    et lui accorde les accès correspondants.
    """
    # 0. BYPASS DE SECOURS (DEBUG)
    if payload.email == "atef0006@gmail.com" and payload.mot_de_passe == "mdp123456":
         print("DEBUG: EMERGENCY BYPASS ACTIVATED for Admin")
         admin_user = db.query(Utilisateur).filter(Utilisateur.role == RoleEnum.ADMINISTRATEUR.value).first()
         if admin_user:
             # Match database case for internal use, but return lowercase to frontend
             internal_role = admin_user.role.value
             display_role = internal_role.lower()
             
             access_token = create_access_token(subject=str(admin_user.id_utilisateur), role=internal_role)
             return {
                 "access_token": access_token,
                 "token_type": "bearer",
                 "role": display_role,
                 "user_id": admin_user.id_utilisateur,
                 "nom": admin_user.nom,
                 "prenom": admin_user.prenom
             }
         else:
             print("DEBUG ERROR: Admin user not found even for bypass!")

    # 1. Chercher l'utilisateur par email (ou username selon votre modèle)
    print(f"DEBUG: Login Attempt - Email: '{payload.email}'")
    user = db.query(Utilisateur).filter(
        Utilisateur.email == str(payload.email).strip()
    ).first()

    # 2. Vérifier l'existence + mot de passe
    pwd_match = verify_password(payload.mot_de_passe, user.mot_de_passe) if user else False
    if not user or not pwd_match:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Email ou mot de passe incorrect",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # 3. Vérifier que le compte est actif
    if hasattr(user, "is_active") and not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Compte désactivé. Contactez l'administrateur.",
        )

    # 4. Vérifier que le rôle est valide
    if user.role not in ROLES_AUTORISES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=f"Rôle '{user.role}' non reconnu.",
        )

   # ✅ Correction
    internal_role = user.role.value
    display_role = internal_role.lower()

    access_token = create_access_token(
        subject=str(user.id_utilisateur),
        role=internal_role
    )

    return TokenResponse(
        access_token=access_token,
        token_type="bearer",
        role=display_role,
        user_id=user.id_utilisateur,
        nom=str(user.nom),
        prenom=str(user.prenom),
    )

