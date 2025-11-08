from sqlalchemy import Column, BigInteger, String, Text, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.base import Base

class Notification(Base):
    __tablename__ = "notifications"

    notification_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id         = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    title           = Column(String(255), nullable=False)
    description     = Column(Text, nullable=False)
    created_at      = Column(DateTime, server_default=func.now(), nullable=False)
    read_at         = Column(DateTime, nullable=True)

    # (khuyến nghị) lưu người gửi để audit
    sender_id       = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)

    user    = relationship("Users", foreign_keys=[user_id])     # người nhận
    sender  = relationship("Users", foreign_keys=[sender_id])   # người gửi
