


from fastapi import APIRouter, HTTPException, HTTPException
from fastapi.params import Depends
from sqlalchemy.orm import Session, joinedload
from app.core.database import get_db
from app.core.security import get_password_hash
from app.models.competence import GroupeTechnicien
from app.models.enums import RoleEnum, StatutPanneEnum, StatutPresenceEnum
from app.models.panne import Panne
from app.models.users import ChefEquipe, Superviseur, Utilisateur, Magasinier
from app.shema.chef_equipe import ChefEquipeCreate, ChefEquipeResponse, ChefEquipeUpdate
from app.shema.superviseur import SuperviseurCreate, SuperviseurResponse, SuperviseurUpdate
from app.shema.magasinier import MagasinierCreate, MagasinierResponse, MagasinierUpdate
from app.shema.user import UtilisateurResponse


router_admin=APIRouter(prefix="/admin", tags=["Admin"])

@router_admin.get("/superviseurs", response_model=list[SuperviseurResponse], summary="Lister tous les superviseurs")
def lister_superviseurs(db: Session = Depends(get_db)):
    superviseurs = db.query(Superviseur).all()
    return [_superviseur_to_response(s) for s in superviseurs]


@router_admin.get("/superviseurs/{id_superviseur}", response_model=SuperviseurResponse, summary="Détail d'un superviseur")
def obtenir_superviseur(id_superviseur: int, db: Session = Depends(get_db)):
    obj = db.query(Superviseur).filter(Superviseur.id_superviseur == id_superviseur).first()
    if not obj:
        raise HTTPException(status_code=404, detail=f"Superviseur id={id_superviseur} introuvable.")
    return _superviseur_to_response(obj)




@router_admin.post(
    "/superviseurs/create",
    response_model=SuperviseurResponse,
    status_code=201
)
def create_superviseur(
    data: SuperviseurCreate,
    db: Session = Depends(get_db)
):

    # 1️⃣ Vérifier si email existe déjà
    existing_user = db.query(Utilisateur).filter(
        Utilisateur.email == data.email
    ).first()

    if existing_user:
        raise HTTPException(status_code=400, detail="Email déjà utilisé")

    # 2️⃣ Créer l'utilisateur
    new_user = Utilisateur(
        nom=data.nom,
        prenom=data.prenom,
        email=data.email,
        mot_de_passe=get_password_hash(data.mot_de_passe),
        role=RoleEnum.SUPERVISEUR.value,
        statut_presence=StatutPresenceEnum.EN_TRAVAIL.value
    )

    db.add(new_user)
    print(f"DEBUG: Creating Superviseur - Role: {new_user.role}, Statut: {new_user.statut_presence}")
    db.commit()
    db.refresh(new_user)

    # 3️⃣ Créer le superviseur lié
    new_superviseur = Superviseur(
        id_utilisateur=new_user.id_utilisateur,
        zone_responsabilite=data.zone_responsabilite
    )

    db.add(new_superviseur)
    db.commit()
    db.refresh(new_superviseur)

    # 4️⃣ Charger avec relation utilisateur
    superviseur = db.query(Superviseur)\
        .options(joinedload(Superviseur.utilisateur))\
        .filter(Superviseur.id_superviseur == new_superviseur.id_superviseur)\
        .first()

    return superviseur

@router_admin.delete("/superviseurs/{id_superviseur}", summary="Supprimer un superviseur")
def supprimer_superviseur(id_superviseur: int, db: Session = Depends(get_db)):
    obj = db.query(Superviseur).filter(Superviseur.id_superviseur == id_superviseur).first()
    if not obj:
        raise HTTPException(status_code=404, detail=f"Superviseur id={id_superviseur} introuvable.")

    # Vérifier s'il a des pannes actives EN_COURS
    
    pannes_actives = (
        db.query(Panne)
        .filter(Panne.id_superviseur == id_superviseur, Panne.statut == StatutPanneEnum.EN_COURS)
        .count()
    )
    if pannes_actives > 0:
        raise HTTPException(
            status_code=409,
            detail=f"Impossible de supprimer : {pannes_actives} panne(s) EN_COURS assignées à ce superviseur.",
        )

    db.delete(obj)
    db.commit()
    return {"message": f"Superviseur id={id_superviseur} supprimé."}


@router_admin.put("/superviseurs/{id_superviseur}", response_model=SuperviseurResponse, summary="Modifier un superviseur")
def modifier_superviseur(id_superviseur: int, data: SuperviseurUpdate, db: Session = Depends(get_db)):
    superviseur = db.query(Superviseur).options(joinedload(Superviseur.utilisateur)).filter(
        Superviseur.id_superviseur == id_superviseur
    ).first()

    if not superviseur:
        raise HTTPException(status_code=404, detail=f"Superviseur id={id_superviseur} introuvable.")

    if data.zone_responsabilite is not None:
        superviseur.zone_responsabilite = data.zone_responsabilite

    db.commit()
    db.refresh(superviseur)

    return SuperviseurResponse(
        id_superviseur=superviseur.id_superviseur,
        id_utilisateur=superviseur.id_utilisateur,
        zone_responsabilite=superviseur.zone_responsabilite,
        utilisateur=UtilisateurResponse(
            id_utilisateur=superviseur.utilisateur.id_utilisateur,
            nom=superviseur.utilisateur.nom,
            prenom=superviseur.utilisateur.prenom,
            email=superviseur.utilisateur.email,
            role=superviseur.utilisateur.role
        )
    )

@router_admin.post("/create-chef", response_model=ChefEquipeResponse, status_code=201)
def create_chef(data: ChefEquipeCreate, db: Session = Depends(get_db)):
    # 1. Vérifier si l'email existe déjà
    existing_user = db.query(Utilisateur).filter(Utilisateur.email == data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email déjà utilisé")
    
    # 2. Créer l'utilisateur
    new_user = Utilisateur(
        nom=data.nom,
        prenom=data.prenom,
        email=data.email,
        mot_de_passe=get_password_hash(data.mot_de_passe),
        role=RoleEnum.CHEF_EQUIPE.value,
        statut_presence=StatutPresenceEnum.EN_TRAVAIL.value
    )
    db.add(new_user)
    print(f"DEBUG: Creating Chef - Role: {new_user.role}, Statut: {new_user.statut_presence}")
    db.commit()
    db.refresh(new_user)

    # 3. Créer le chef d'équipe lié
    new_chef = ChefEquipe(
        id_utilisateur=new_user.id_utilisateur,
        id_groupe_supervise=data.id_groupe_supervise
    )
    db.add(new_chef)
    db.commit()
    db.refresh(new_chef)

    # 4. Retourner le chef avec les infos utilisateur
    return db.query(ChefEquipe)\
        .options(joinedload(ChefEquipe.utilisateur))\
        .filter(ChefEquipe.id_chef == new_chef.id_chef)\
        .first()



@router_admin.delete("/chefs-equipe/{id_chef}", status_code=204, summary="Supprimer un chef d'équipe")
def supprimer_chef_equipe(id_chef: int, db: Session = Depends(get_db)):
    # 1. Chercher le chef d'équipe
    chef = db.query(ChefEquipe).filter(ChefEquipe.id_chef == id_chef).first()
    if not chef:
        raise HTTPException(status_code=404, detail=f"ChefEquipe id={id_chef} introuvable.")
    
    # 2. Supprimer le chef d'équipe
    db.delete(chef)
    db.commit()
    
    # 204 No Content => pas de retour
    return

@router_admin.put("/chefs-equipe/{id_chef}/groupe", response_model=ChefEquipeResponse, summary="Mettre à jour le groupe supervisé par le chef d'équipe")
def update_groupe_chef(
    id_chef: int,
    data: ChefEquipeUpdate,  # contiendra uniquement id_groupe_supervise
    db: Session = Depends(get_db)
):
    # Vérifier que le chef existe
    chef = db.query(ChefEquipe).filter(ChefEquipe.id_chef == id_chef).first()
    if not chef:
        raise HTTPException(status_code=404, detail=f"ChefEquipe id={id_chef} introuvable.")
    
    # Vérifier que le groupe existe
    if data.id_groupe_supervise is not None:
        groupe = db.query(GroupeTechnicien).filter(
            GroupeTechnicien.id_groupe_tech == data.id_groupe_supervise
        ).first()
        if not groupe:
            raise HTTPException(
                status_code=404,
                detail=f"GroupeTechnicien id={data.id_groupe_supervise} introuvable."
            )

    # Mettre à jour le groupe supervisé
    chef.id_groupe_supervise = data.id_groupe_supervise
    db.commit()
    db.refresh(chef)

    return chef


# --- MAGASINIERS ---

@router_admin.get("/magasiniers", response_model=list[MagasinierResponse], summary="Lister tous les magasiniers")
def lister_magasiniers(db: Session = Depends(get_db)):
    magasiniers = db.query(Magasinier).options(joinedload(Magasinier.utilisateur)).all()
    return magasiniers

@router_admin.post("/magasiniers/create", response_model=MagasinierResponse, status_code=201, summary="Créer un magasinier")
def create_magasinier(data: MagasinierCreate, db: Session = Depends(get_db)):
    # 1. Vérifier si l'email existe déjà
    existing_user = db.query(Utilisateur).filter(Utilisateur.email == data.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email déjà utilisé")
    
    # 2. Créer l'utilisateur
    new_user = Utilisateur(
        nom=data.nom,
        prenom=data.prenom,
        email=data.email,
        mot_de_passe=get_password_hash(data.mot_de_passe),
        role=RoleEnum.MAGASINIER.value,
        statut_presence=StatutPresenceEnum.EN_TRAVAIL.value
    )
    db.add(new_user)
    print(f"DEBUG: Creating Magasinier - Role: {new_user.role}, Statut: {new_user.statut_presence}")
    db.commit()
    db.refresh(new_user)

    # 3. Créer le magasinier lié
    new_magasinier = Magasinier(id_utilisateur=new_user.id_utilisateur)
    db.add(new_magasinier)
    db.commit()
    
    # 4. Charger avec relation
    return db.query(Magasinier).options(joinedload(Magasinier.utilisateur)).filter(Magasinier.id_magasinier == new_magasinier.id_magasinier).first()

@router_admin.delete("/magasiniers/{id_magasinier}", status_code=204, summary="Supprimer un magasinier")
def supprimer_magasinier(id_magasinier: int, db: Session = Depends(get_db)):
    magasinier = db.query(Magasinier).filter(Magasinier.id_magasinier == id_magasinier).first()
    if not magasinier:
        raise HTTPException(status_code=404, detail="Magasinier introuvable")
    
    # La suppression de l'utilisateur supprimera le magasinier par CASCADE si configurée
    user = db.query(Utilisateur).filter(Utilisateur.id_utilisateur == magasinier.id_utilisateur).first()
    if user:
        db.delete(user)
    else:
        db.delete(magasinier)
        
    db.commit()
    return

@router_admin.get("/chef-by-group/{id_groupe}", response_model=ChefEquipeResponse, summary="Trouver le chef d'un groupe")
def get_chef_by_group(id_groupe: int, db: Session = Depends(get_db)):
    chef = db.query(ChefEquipe)\
        .options(joinedload(ChefEquipe.utilisateur))\
        .filter(ChefEquipe.id_groupe_supervise == id_groupe)\
        .first()
    if not chef:
        raise HTTPException(status_code=404, detail="Aucun chef trouvé pour ce groupe")
    return chef