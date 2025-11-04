from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.models.notifications import Notifications
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/notifications", tags=["Notifications"])

class NotifSchema(BaseModel):
    user_id: int
    title: str
    description: str

@router.get("/")
def list_notifications(user_id: int, db: Session = Depends(get_db)):
    return db.query(Notifications).filter(Notifications.user_id == user_id).order_by(Notifications.created_at.desc()).all()

@router.post("/")
def create_notification(data: NotifSchema, db: Session = Depends(get_db)):
    notif = Notifications(**data.dict(), created_at=datetime.utcnow())
    db.add(notif)
    db.commit()
    return {"message": "Đã gửi thông báo"}
