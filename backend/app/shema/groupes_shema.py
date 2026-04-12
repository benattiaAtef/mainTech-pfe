from typing import Optional

from pydantic import BaseModel, Field


class GroupeMachineBase(BaseModel):
    nom_groupe: str = Field(..., min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=255)


class GroupeMachineCreate(GroupeMachineBase):
    pass


class GroupeMachineUpdate(BaseModel):
    nom_groupe: Optional[str] = Field(None, min_length=1, max_length=50)
    description: Optional[str] = Field(None, max_length=255)


class GroupeMachineResponse(GroupeMachineBase):
    id: int
    nombre_machines: Optional[int] = 0

    class Config:
        from_attributes = True
