# app/models/notification.py
from sqlalchemy import Column, BigInteger, String, Text, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.database import Base

class Notifications(Base):
    __tablename__ = "notifications"

    notification_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id         = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    title           = Column(String(255), nullable=False)
    description     = Column(Text, nullable=False)
    created_at      = Column(DateTime, server_default=func.now(), nullable=False)
    read_at         = Column(DateTime, nullable=True)

    sender_id       = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    # User là NGƯỜI NHẬN
    user = relationship(
        "Users",
        foreign_keys=[user_id],
        back_populates="notifications"
    )

    # User là NGƯỜI GỬI
    sender = relationship(
        "Users",
        foreign_keys=[sender_id],
        back_populates="notifications_sent"
    )
