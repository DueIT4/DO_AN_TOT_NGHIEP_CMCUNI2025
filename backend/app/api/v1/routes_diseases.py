from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.models.diseases import Disease
from pydantic import BaseModel

router = APIRouter(prefix="/diseases", tags=["Diseases"])

class DiseaseSchema(BaseModel):
    name: str
    description: str
    treatment_guideline: str

@router.get("/")
def list_diseases(db: Session = Depends(get_db)):
    return db.query(Disease).all()

@router.post("/")
def add_disease(data: DiseaseSchema, db: Session = Depends(get_db)):
    dis = Disease(**data.dict())
    db.add(dis)
    db.commit()
    return {"message": "Đã thêm bệnh mới"}
