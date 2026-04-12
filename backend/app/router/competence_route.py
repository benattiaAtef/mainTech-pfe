from fastapi import APIRouter, Depends, HTTPException, HTTPException
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.core.security import require_role
from app.models.competence import CompetenceTechnicien
from app.models.enums import RoleEnum
from app.shema.competence import CompetenceTechnicienCreate


router_competences = APIRouter(prefix="/competences", tags=["Compétences"])


@router_competences.post("/create")
async def add_competence(
    competence_data: CompetenceTechnicienCreate,
    user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF - Ajouter compétence technicien"""
    nouvelle_competence = CompetenceTechnicien(**competence_data.dict())
    db.add(nouvelle_competence)
    db.commit()
    db.refresh(nouvelle_competence)
    return nouvelle_competence




@router_competences.get("/technicien/{technicien_id}")
async def get_competences_tech(
    technicien_id: int,
    current_user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """✅ TOUS - Compétences d'un technicien"""
    competences = db.query(CompetenceTechnicien).filter(
        CompetenceTechnicien.id_technicien == technicien_id
    ).all()
    return competences


@router_competences.delete("/{competence_id}")
async def remove_competence(
    competence_id: int,
    user = Depends(require_role(RoleEnum.ADMINISTRATEUR, RoleEnum.CHEF_EQUIPE)),
    db: Session = Depends(get_db)
):
    """🔒 ADMIN, CHEF - Retirer compétence"""
    competence = db.query(CompetenceTechnicien).filter(
        CompetenceTechnicien.id_competence == competence_id
    ).first()
    if not competence:
        raise HTTPException(status_code=404, detail="Compétence introuvable")
    db.delete(competence)
    db.commit()
    return {"message": "Compétence supprimée"}