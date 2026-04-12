from datetime import date
from http.client import HTTPException

from fastapi import APIRouter, Depends,status

from app.core.database import get_db
from app.core.security import require_role
from app.models.enums import RoleEnum
from app.models.machine import Machine
from app.models.panne import HistoriquePanne, Panne
from app.shema.historique_panne import HistoriquePanneCreate, HistoriquePanneDetailResponse, HistoriquePanneResponse, HistoriquePanneUpdate
from sqlalchemy.orm import Session, joinedload

router_historique = APIRouter(prefix="/historique-pannes", tags=["Historique Pannes"])


@router_historique.get(
    "/",
    response_model=list[HistoriquePanneDetailResponse],
    summary="Lister tout l'historique des pannes",
)
def lister_historique(
    skip: int = 0,
    limit: int = 100,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR
    )),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF, SUPERVISEUR - Liste l'historique complet des pannes"""
    return (
        db.query(HistoriquePanne)
        .options(
            joinedload(HistoriquePanne.machine),
            joinedload(HistoriquePanne.type_panne),
        )
        .offset(skip)
        .limit(limit)
        .all()
    )


@router_historique.get(
    "/machine/{id_machine}",
    response_model=list[HistoriquePanneDetailResponse],
    summary="Historique des pannes d'une machine",
)
def historique_par_machine(
    id_machine: int,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR
    )),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF, SUPERVISEUR - Historique des pannes d'une machine"""
    machine = db.query(Machine).filter(Machine.id_machine == id_machine).first()
    if not machine:
        raise HTTPException(status_code=404, detail=f"Machine id={id_machine} introuvable.")

    return (
        db.query(HistoriquePanne)
        .options(joinedload(HistoriquePanne.type_panne))
        .filter(HistoriquePanne.id_machine == id_machine)
        .all()
    )

@router_historique.post(
    "/create",
    response_model=HistoriquePanneResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Créer une entrée d'historique manuellement",
)
def creer_historique(
    data: HistoriquePanneCreate,
    current_user=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.SUPERVISEUR)),
    db: Session = Depends(get_db),
):
    """
    🔒 ADMIN, SUPERVISEUR - Créer manuellement une entrée d'historique.

    En pratique, l'historique est alimenté automatiquement
    lors de la résolution d'une panne.
    """
    panne = db.query(Panne).filter(Panne.id_panne == data.id_panne).first()
    if not panne:
        raise HTTPException(status_code=404, detail=f"Panne id={data.id_panne} introuvable.")

    existing = db.query(HistoriquePanne).filter(
        HistoriquePanne.id_panne == data.id_panne
    ).first()
    if existing:
        raise HTTPException(
            status_code=409,
            detail=f"Un historique existe déjà pour la panne id={data.id_panne}."
        )

    historique = HistoriquePanne(
        id_panne=panne.id_panne,
        id_type_panne=panne.id_type_panne,
        id_machine=panne.id_machine,
        frequence_panne=data.frequence_panne,
        dernie_panne=data.dernie_panne or date.today(),
    )
    db.add(historique)
    db.commit()
    db.refresh(historique)
    return historique

@router_historique.get(
    "/panne/{id_panne}",
    response_model=HistoriquePanneDetailResponse,
    summary="Historique d'une panne spécifique",
)
def historique_par_panne(
    id_panne: int,
    current_user=Depends(require_role(
        RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE, RoleEnum.SUPERVISEUR
    )),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF, SUPERVISEUR - Historique d'une panne par son id"""
    historique = (
        db.query(HistoriquePanne)
        .options(
            joinedload(HistoriquePanne.machine),
            joinedload(HistoriquePanne.type_panne),
        )
        .filter(HistoriquePanne.id_panne == id_panne)
        .first()
    )
    if not historique:
        raise HTTPException(status_code=404, detail=f"Historique pour panne id={id_panne} introuvable.")
    return historique


@router_historique.put(
    "/{id_panne}",
    response_model=HistoriquePanneResponse,
    summary="Mettre à jour un historique de panne",
)
def update_historique(
    id_panne: int,
    data: HistoriquePanneUpdate,
    current_user=Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN, CHEF - Mettre à jour la fréquence ou la date de dernière panne"""
    historique = db.query(HistoriquePanne).filter(
        HistoriquePanne.id_panne == id_panne
    ).first()
    if not historique:
        raise HTTPException(status_code=404, detail=f"Historique pour panne id={id_panne} introuvable.")

    if data.frequence_panne is not None:
        historique.frequence_panne = data.frequence_panne
    if data.dernie_panne is not None:
        historique.dernie_panne = data.dernie_panne

    db.commit()
    db.refresh(historique)
    return historique



@router_historique.delete(
    "/{id_panne}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Supprimer une entrée d'historique",
)
def supprimer_historique(
    id_panne: int,
    admin=Depends(require_role(RoleEnum.ADMINISTRATEUR)),
    db: Session = Depends(get_db),
):
    """🔒 ADMIN - Supprimer une entrée d'historique de panne"""
    historique = db.query(HistoriquePanne).filter(
        HistoriquePanne.id_panne == id_panne
    ).first()
    if not historique:
        raise HTTPException(status_code=404, detail=f"Historique pour panne id={id_panne} introuvable.")

    db.delete(historique)
    db.commit()
    return
