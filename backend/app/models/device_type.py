import enum
from sqlalchemy import (
    Column,
    BigInteger,
    String,
    Boolean,
    Enum as SAEnum,
    DateTime,
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base


class DeviceTypeStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"


class DeviceType(Base):
    __tablename__ = "device_type"

    device_type_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_type_name = Column(String(255), unique=True, nullable=False)
    has_stream = Column(Boolean, nullable=False, default=False)
    status = Column(SAEnum(DeviceTypeStatus), default=DeviceTypeStatus.active)
    created_at = Column(DateTime, server_default=func.now())

    # quan hệ ngược với Device (nếu bạn đã có model Device)
    devices = relationship("Device", back_populates="device_type")
