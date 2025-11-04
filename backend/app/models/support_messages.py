from sqlalchemy import Column, BigInteger, ForeignKey, Text, String, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base

class SupportMessages(Base):
    __tablename__ = "support_messages"

    message_id = Column(BigInteger, primary_key=True, autoincrement=True)
    ticket_id = Column(BigInteger, ForeignKey("support_tickets.ticket_id", ondelete="CASCADE"), nullable=False)
    sender_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"))
    message = Column(Text)
    attachment_url = Column(String(700))
    created_at = Column(TIMESTAMP, server_default=func.now())
