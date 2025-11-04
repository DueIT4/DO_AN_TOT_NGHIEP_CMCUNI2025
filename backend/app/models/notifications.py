from sqlalchemy import Column, BigInteger, ForeignKey, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base

class Notifications(Base):
    __tablename__ = "notifications"

    notification_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    created_at = Column(TIMESTAMP, server_default=func.now())
    read_at = Column(TIMESTAMP)
