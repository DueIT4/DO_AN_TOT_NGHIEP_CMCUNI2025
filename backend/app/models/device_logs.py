# app/models/device_logs.py
from sqlalchemy import (
    Column, BigInteger, String, Text, ForeignKey, DateTime, Enum
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
#from app.core.database import Base  # chỉnh lại nếu bạn dùng module khác
from app.db.base import Base

class DeviceLogs(Base):
    __tablename__ = "device_logs"

    log_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(
        BigInteger,
        ForeignKey("devices.device_id", ondelete="CASCADE"),
        nullable=False
    )
    event_type = Column(
        Enum("online", "offline", "error", "maintenance", name="device_event_type"),
        nullable=False
    )
    description = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    # Quan hệ ngược với Device.logs
    device = relationship("Device", back_populates="logs")