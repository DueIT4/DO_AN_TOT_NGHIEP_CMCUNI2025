from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class TicketStatus(str, Enum):
    processing = "processing"
    processed = "processed"

# ----- Tickets -----
class SupportTicketCreate(BaseModel):
    title: str = Field(..., max_length=255)
    description: str

class SupportTicketOut(BaseModel):
    ticket_id: int
    user_id: int
    title: str
    description: str
    status: TicketStatus
    created_at: datetime

    class Config:
        from_attributes = True

class SupportTicketWithMessages(SupportTicketOut):
    messages_count: int
    # có thể bổ sung messages nếu muốn trả full

# ----- Messages -----
class SupportMessageCreate(BaseModel):
    ticket_id: int
    message: str

class SupportMessageOut(BaseModel):
    message_id: int
    ticket_id: int
    sender_id: Optional[int]
    message: str
    attachment_url: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True
