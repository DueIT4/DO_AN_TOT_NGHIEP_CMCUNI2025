from sqlalchemy import (
    Column, BigInteger, String, Enum, ForeignKey,
    DateTime
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

#from app.core.database import Base
from app.db.base import Base

class Device(Base):
    __tablename__ = "devices"

    device_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id"), nullable=True)
    name = Column(String(255))
    device_type_id = Column(BigInteger, ForeignKey("device_type.device_type_id"), nullable=False)
    parent_device_id = Column(BigInteger, ForeignKey("devices.device_id"), nullable=True)
    serial_no = Column(String(100), unique=True)
    location = Column(String(255))
    status = Column(
        Enum("active", "maintain", "inactive", name="device_status"),
        nullable=False,
        default="active"
    )
    stream_url = Column(String(700))
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # quan hệ
    user = relationship("Users", back_populates="devices")
    device_type = relationship("DeviceType", back_populates="devices")
    parent = relationship("Device", remote_side=[device_id])
    sensor_readings = relationship("SensorReadings", back_populates="device")
    images = relationship("Img", back_populates="device")
    logs = relationship("DeviceLogs", back_populates="device")