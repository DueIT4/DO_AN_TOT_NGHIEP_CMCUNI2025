from sqlalchemy import (
    Column, BigInteger, String, Enum, DateTime, ForeignKey, Numeric
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class SensorReadings(Base):
    __tablename__ = "sensor_readings"

    reading_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(BigInteger, ForeignKey("devices.device_id"), nullable=False)

    metric = Column(String(255), nullable=False)
    value_num = Column(Numeric(10, 3))
    unit = Column(String(20))
    status = Column(Enum("ok", "error", "missing", name="sensor_status"), default="ok")
    recorded_at = Column(DateTime, server_default=func.now())

    device = relationship("Device", back_populates="sensor_readings")
