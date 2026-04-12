



from http.client import HTTPException

from fastapi import APIRouter, Depends,status

from app.core.database import get_db
from app.core.security import require_role
from app.models.enums import GraviteEnum, RoleEnum
from app.models.panne import TypePanne
from app.shema.type_panne import TypePanneCreate, TypePanneResponse, TypePanneUpdate, TypePanneWithCountResponse
from sqlalchemy.orm import Session

router_type_panne = APIRouter(prefix="/types-pannes", tags=["Types de Pannes"])


@router_type_panne.get(
    "/",
    response_model=list[TypePanneResponse],
    summary="Lister tous les types de pannes",
)
def lister_types_pannes(
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE,
        RoleEnum.SUPERVISEUR, RoleEnum.TECHNICIEN,
    )),
    db: Session = Depends(get_db),
):
    """✅ TOUS - Liste de tous les types de pannes"""
    return db.query(TypePanne).all()

@router_type_panne.get(
    "/{id_type_panne}",
    response_model=TypePanneWithCountResponse,
    summary="Détail d'un type de panne avec nombre de pannes associées",
)
def obtenir_type_panne(
    id_type_panne: int,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE,
        RoleEnum.SUPERVISEUR, RoleEnum.TECHNICIEN,
    )),
    db: Session = Depends(get_db),
):
    """✅ TOUS - Détail d'un type de panne"""
    obj = db.query(TypePanne).filter(TypePanne.id_type_panne == id_type_panne).first()
    if not obj:
        raise HTTPException(status_code=404, detail=f"TypePanne id={id_type_panne} introuvable.")

    return TypePanneWithCountResponse(
        id_type_panne=obj.id_type_panne,
        nom_panne=obj.nom_panne,
        gravite=obj.gravite,
        nombre_pannes=len(obj.pannes),
    )



@router_type_panne.get(
    "/gravite/{gravite}",
    response_model=list[TypePanneResponse],
    summary="Filtrer les types de pannes par gravité",
)
def types_par_gravite(
    gravite: GraviteEnum,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR
    )),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF, SUPERVISEUR - Types de pannes filtrés par gravité"""
    return db.query(TypePanne).filter(TypePanne.gravite == gravite).all()


@router_type_panne.post(
    "/create",
    response_model=TypePanneResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer un type de panne",
)
def creer_type_panne(
    data: TypePanneCreate,
    admin=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN - Créer un nouveau type de panne"""
    existing = db.query(TypePanne).filter(TypePanne.nom_panne == data.nom_panne).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail=f"Un type de panne nommé '{data.nom_panne}' existe déjà."
        )

    nouveau_type = TypePanne(
        nom_panne=data.nom_panne,
        gravite=data.gravite,
    )
    db.add(nouveau_type)
    db.commit()
    db.refresh(nouveau_type)
    return nouveau_type


@router_type_panne.put(
    "/{id_type_panne}",
    response_model=TypePanneResponse,
    summary="Modifier un type de panne",
)
def modifier_type_panne(
    id_type_panne: int,
    data: TypePanneUpdate,
    admin=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN - Modifier un type de panne existant"""
    obj = db.query(TypePanne).filter(TypePanne.id_type_panne == id_type_panne).first()
    if not obj:
        raise HTTPException(status_code=404, detail=f"TypePanne id={id_type_panne} introuvable.")

    if data.nom_panne is not None:
        duplicate = db.query(TypePanne).filter(
            TypePanne.nom_panne == data.nom_panne,
            TypePanne.id_type_panne != id_type_panne,
        ).first()
        if duplicate:
            raise HTTPException(
                status_code=409,
                detail=f"Un type de panne nommé '{data.nom_panne}' existe déjà."
            )
        obj.nom_panne = data.nom_panne

    if data.gravite is not None:
        obj.gravite = data.gravite

    db.commit()
    db.refresh(obj)
    return obj




@router_type_panne.delete(
    "/{id_type_panne}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Supprimer un type de panne",
)
def supprimer_type_panne(
    id_type_panne: int,
    admin=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN - Supprimer un type de panne (interdit si des pannes l'utilisent)"""
    obj = db.query(TypePanne).filter(TypePanne.id_type_panne == id_type_panne).first()
    if not obj:
        raise HTTPException(status_code=404, detail=f"TypePanne id={id_type_panne} introuvable.")

    if obj.pannes:
        raise HTTPException(
            status_code=409,
            detail=f"Impossible de supprimer : {len(obj.pannes)} panne(s) utilisent ce type.",
        )

    db.delete(obj)
    db.commit()
    return