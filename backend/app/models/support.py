from sqlalchemy import Column, BigInteger, String, Text, Enum, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum

class TicketStatus(str, enum.Enum):
    processing = "processing"
    processed = "processed"

class SupportTicket(Base):
    __tablename__ = "support_tickets"

    ticket_id   = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id     = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    title       = Column(String(255), nullable=False)
    description = Column(Text, nullable=False)
    status      = Column(Enum(TicketStatus), nullable=False, default=TicketStatus.processing)
    created_at  = Column(DateTime, server_default=func.now(), nullable=False)

    user        = relationship("Users", backref="tickets")
    messages    = relationship("SupportMessage", cascade="all, delete-orphan", backref="ticket", order_by="SupportMessage.created_at")

class SupportMessage(Base):
    __tablename__ = "support_messages"

    message_id     = Column(BigInteger, primary_key=True, autoincrement=True)
    ticket_id      = Column(BigInteger, ForeignKey("support_tickets.ticket_id", ondelete="CASCADE"), nullable=False)
    sender_id      = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"))
    message        = Column(Text, nullable=False)
    attachment_url = Column(String(700), nullable=True)
    created_at     = Column(DateTime, server_default=func.now(), nullable=False)

    sender         = relationship("Users")
