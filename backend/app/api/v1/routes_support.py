from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.models.support_tickets import SupportTickets
from app.models.support_messages import SupportMessages
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/support", tags=["Support"])

class TicketSchema(BaseModel):
    user_id: int
    title: str
    description: str

class MessageSchema(BaseModel):
    ticket_id: int
    sender_id: int
    message: str

@router.post("/ticket")
def create_ticket(data: TicketSchema, db: Session = Depends(get_db)):
    t = SupportTickets(**data.dict(), created_at=datetime.utcnow())
    db.add(t); db.commit()
    return {"message": "Đã gửi yêu cầu hỗ trợ", "ticket_id": t.ticket_id}

@router.post("/message")
def send_message(data: MessageSchema, db: Session = Depends(get_db)):
    msg = SupportMessages(**data.dict(), created_at=datetime.utcnow())
    db.add(msg); db.commit()
    return {"message": "Đã gửi phản hồi"}
