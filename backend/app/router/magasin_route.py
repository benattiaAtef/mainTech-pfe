from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session, joinedload
from app.core.database import get_db
from app.core.security import get_current_user
from app.models.magasin import PieceRechange, DemandeRechange, StatutDemandeEnum
from app.models.enums import RoleEnum
from app.shema.magasin import (
    PieceRechangeCreate, PieceRechangeUpdate, PieceRechangeOut,
    DemandeRechangeCreate, DemandeStatutUpdate, DemandeRechangeOut,
    DemandeRechangeBatchCreate
)
from app.models.users import Utilisateur
from app.models.intervention import Intervention

router_magasin = APIRouter(prefix="/magasin", tags=["Magasin"])


# ─────────────────────────────────────────────
#  Catalogue des pièces
# ─────────────────────────────────────────────

@router_magasin.get("/pieces", response_model=list[PieceRechangeOut])
def list_pieces(
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Lister toutes les pièces du magasin (accessible à tous les rôles)."""
    return db.query(PieceRechange).order_by(PieceRechange.nom).all()


@router_magasin.post("/pieces", response_model=PieceRechangeOut, status_code=status.HTTP_201_CREATED)
def create_piece(
    data: PieceRechangeCreate,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Créer une pièce dans le magasin."""
    if current_user.role not in (RoleEnum.ADMINISTRATEUR, RoleEnum.SUPERVISEUR, RoleEnum.MAGASINIER):
        raise HTTPException(status_code=403, detail="Accès refusé")
    # Vérifier référence unique
    if db.query(PieceRechange).filter(PieceRechange.reference == data.reference).first():
        raise HTTPException(status_code=400, detail="Une pièce avec cette référence existe déjà")
    piece = PieceRechange(**data.model_dump())
    db.add(piece)
    db.commit()
    db.refresh(piece)
    return piece


@router_magasin.put("/pieces/{id_piece}", response_model=PieceRechangeOut)
def update_piece(
    id_piece: int,
    data: PieceRechangeUpdate,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Modifier une pièce."""
    if current_user.role not in (RoleEnum.ADMINISTRATEUR, RoleEnum.SUPERVISEUR, RoleEnum.MAGASINIER):
        raise HTTPException(status_code=403, detail="Accès refusé")
    piece = db.query(PieceRechange).filter(PieceRechange.id_piece == id_piece).first()
    if not piece:
        raise HTTPException(status_code=404, detail="Pièce introuvable")
    for field, value in data.model_dump(exclude_none=True).items():
        setattr(piece, field, value)
    db.commit()
    db.refresh(piece)
    return piece


@router_magasin.delete("/pieces/{id_piece}", status_code=status.HTTP_204_NO_CONTENT)
def delete_piece(
    id_piece: int,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Supprimer une pièce."""
    if current_user.role not in (RoleEnum.ADMINISTRATEUR, RoleEnum.MAGASINIER):
        raise HTTPException(status_code=403, detail="Accès refusé")
    piece = db.query(PieceRechange).filter(PieceRechange.id_piece == id_piece).first()
    if not piece:
        raise HTTPException(status_code=404, detail="Pièce introuvable")
    db.delete(piece)
    db.commit()


# ─────────────────────────────────────────────
#  Demandes de pièces
# ─────────────────────────────────────────────

@router_magasin.post("/demandes", response_model=DemandeRechangeOut, status_code=status.HTTP_201_CREATED)
def creer_demande(
    data: DemandeRechangeCreate,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Un technicien demande une pièce pour son intervention en cours."""
    # Vérifier que l'intervention existe
    intervention = db.query(Intervention).filter(
        Intervention.id_intervention == data.id_intervention
    ).first()
    if not intervention:
        raise HTTPException(status_code=404, detail="Intervention introuvable")

    # Vérifier que la pièce existe
    piece = db.query(PieceRechange).filter(PieceRechange.id_piece == data.id_piece).first()
    if not piece:
        raise HTTPException(status_code=404, detail="Pièce introuvable")

    if piece.quantite_stock < data.quantite_demandee:
        raise HTTPException(
            status_code=400,
            detail=f"Stock insuffisant. Disponible : {piece.quantite_stock} {piece.unite}"
        )

    demande = DemandeRechange(**data.model_dump())
    db.add(demande)
    db.commit()
    db.refresh(demande)
    # Recharger avec la piece jointe
    return db.query(DemandeRechange).options(
        joinedload(DemandeRechange.piece)
    ).filter(DemandeRechange.id_demande == demande.id_demande).first()


@router_magasin.post("/demandes/batch", response_model=list[DemandeRechangeOut], status_code=status.HTTP_201_CREATED)
def demander_pieces_batch(
    data: DemandeRechangeBatchCreate,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Créer plusieurs demandes de pièces en une seule fois."""
    created_demandes = []
    for item in data.demandes:
        # Vérifier intervention
        interv = db.query(Intervention).filter(Intervention.id_intervention == item.id_intervention).first()
        if not interv:
            continue # Ou lever une erreur
            
        # Vérifier pièce
        piece = db.query(PieceRechange).filter(PieceRechange.id_piece == item.id_piece).first()
        if not piece:
            continue

        demande = DemandeRechange(**item.model_dump())
        db.add(demande)
        created_demandes.append(demande)
    
    db.commit()
    
    # Recharger avec les pièces jointes
    ids = [d.id_demande for d in created_demandes]
    return db.query(DemandeRechange).options(
        joinedload(DemandeRechange.piece)
    ).filter(DemandeRechange.id_demande.in_(ids)).all()


@router_magasin.get("/demandes", response_model=list[DemandeRechangeOut])
def list_demandes(
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Lister toutes les demandes."""
    if current_user.role not in (RoleEnum.ADMINISTRATEUR, RoleEnum.SUPERVISEUR, RoleEnum.MAGASINIER):
        raise HTTPException(status_code=403, detail="Accès refusé")
    return db.query(DemandeRechange).options(
        joinedload(DemandeRechange.piece)
    ).order_by(DemandeRechange.date_demande.desc()).all()


@router_magasin.get("/demandes/intervention/{id_intervention}", response_model=list[DemandeRechangeOut])
def list_demandes_by_intervention(
    id_intervention: int,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Lister les demandes d'une intervention spécifique."""
    return db.query(DemandeRechange).options(
        joinedload(DemandeRechange.piece)
    ).filter(
        DemandeRechange.id_intervention == id_intervention
    ).order_by(DemandeRechange.date_demande.desc()).all()


@router_magasin.put("/demandes/{id_demande}/statut", response_model=DemandeRechangeOut)
def changer_statut_demande(
    id_demande: int,
    data: DemandeStatutUpdate,
    db: Session = Depends(get_db),
    current_user: Utilisateur = Depends(get_current_user)
):
    """Changer le statut d'une demande. Si 'livree', décrémente le stock."""
    try:
        new_statut = StatutDemandeEnum(data.statut)
    except ValueError:
        raise HTTPException(status_code=400, detail=f"Statut invalide: {data.statut}")

    # Vérification des permissions
    # L'admin/magasinier peut tout changer
    # Le technicien peut seulement confirmer réception ('livree') si c'est 'approuvee'
    is_admin = current_user.role in (RoleEnum.ADMINISTRATEUR, RoleEnum.SUPERVISEUR, RoleEnum.MAGASINIER)
    is_tech = current_user.role == RoleEnum.TECHNICIEN

    demande = db.query(DemandeRechange).options(
        joinedload(DemandeRechange.piece)
    ).filter(DemandeRechange.id_demande == id_demande).first()

    if not demande:
        raise HTTPException(status_code=404, detail="Demande introuvable")

    if not is_admin:
        if is_tech:
            if new_statut == StatutDemandeEnum.LIVREE:
                if demande.statut != StatutDemandeEnum.APPROUVEE:
                    raise HTTPException(status_code=400, detail="Vous ne pouvez confirmer que les pièces déjà approuvées")
            else:
                raise HTTPException(status_code=403, detail="Vous n'avez pas le droit de changer ce statut")
        else:
            raise HTTPException(status_code=403, detail="Accès refusé")

    # Décrémenter le stock lors de la livraison
    if new_statut == StatutDemandeEnum.LIVREE and demande.statut != StatutDemandeEnum.LIVREE:
        piece = db.query(PieceRechange).filter(PieceRechange.id_piece == demande.id_piece).first()
        if piece:
            if piece.quantite_stock < demande.quantite_demandee:
                raise HTTPException(status_code=400, detail="Stock insuffisant pour livrer")
            piece.quantite_stock -= demande.quantite_demandee

    demande.statut = new_statut
    db.commit()
    db.refresh(demande)
    return db.query(DemandeRechange).options(
        joinedload(DemandeRechange.piece)
    ).filter(DemandeRechange.id_demande == id_demande).first()
