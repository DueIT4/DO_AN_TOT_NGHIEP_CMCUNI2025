from sqlalchemy import Column, BigInteger, ForeignKey, String, Text, Enum, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base
import enum

class TicketStatus(str, enum.Enum):
    processing = "processing"
    processed = "processed"

class SupportTickets(Base):
    __tablename__ = "support_tickets"

    ticket_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    status = Column(Enum(TicketStatus), default=TicketStatus.processing)
    created_at = Column(TIMESTAMP, server_default=func.now())
