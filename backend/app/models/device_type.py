from sqlalchemy import Column, BigInteger, String, Boolean, Enum, DateTime
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class DeviceType(Base):
    __tablename__ = "device_type"

    device_type_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_type_name = Column(String(255), unique=True, nullable=False)
    has_stream = Column(Boolean, nullable=False, default=False)
    status = Column(Enum("active", "inactive", name="device_type_status"), default="active")
    created_at = Column(DateTime, server_default=func.now())

    devices = relationship("Device", back_populates="device_type")
