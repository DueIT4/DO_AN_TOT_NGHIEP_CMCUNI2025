from sqlalchemy import Column, BigInteger, String, Boolean, Enum, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base
import enum

class DeviceStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"

class DeviceType(Base):
    __tablename__ = "device_type"

    device_type_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_type_name = Column(String(255), unique=True, nullable=False)
    has_stream = Column(Boolean, default=False)
    status = Column(Enum(DeviceStatus), default=DeviceStatus.active)
    created_at = Column(TIMESTAMP, server_default=func.now())
