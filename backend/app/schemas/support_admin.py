# app/schemas/support_admin.py
from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel


class AdminTicketListItem(BaseModel):
    ticket_id: int
    user_id: int
    username: Optional[str] = None
    title: str
    status: str
    created_at: datetime

    class Config:
        orm_mode = True


class AdminTicketList(BaseModel):
    total: int
    items: List[AdminTicketListItem]


class AdminSupportMessageOut(BaseModel):
    message_id: int
    ticket_id: int
    sender_id: Optional[int] = None
    sender_name: Optional[str] = None
    message: str
    attachment_url: Optional[str] = None
    created_at: datetime

    class Config:
        orm_mode = True


class AdminTicketDetail(BaseModel):
    ticket_id: int
    user_id: int
    username: Optional[str] = None
    title: str
    description: Optional[str] = None
    status: str
    created_at: datetime
    messages: List[AdminSupportMessageOut]
