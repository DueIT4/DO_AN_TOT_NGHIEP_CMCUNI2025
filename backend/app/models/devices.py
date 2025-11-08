from sqlalchemy import Column, BigInteger, String, Enum, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.db import Base
import enum

class DeviceState(str, enum.Enum):
    active = "active"
    maintain = "maintain"
    inactive = "inactive"

class Devices(Base):
    __tablename__ = "devices"

    device_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"))
    name = Column(String(255))
    device_type_id = Column(BigInteger, ForeignKey("device_type.device_type_id", ondelete="RESTRICT"), nullable=False)
    parent_device_id = Column(BigInteger, ForeignKey("devices.device_id", ondelete="SET NULL"))
    serial_no = Column(String(100), unique=True)
    location = Column(String(255))
    status = Column(Enum(DeviceState), default=DeviceState.active)
    stream_url = Column(String(700))
    created_at = Column(TIMESTAMP, server_default=func.now())
    updated_at = Column(TIMESTAMP, onupdate=func.now())
    
    # Relationships
    device_type = relationship("DeviceType", backref="devices", lazy="joined")
    parent_device = relationship("Devices", remote_side=[device_id], backref="child_devices")
