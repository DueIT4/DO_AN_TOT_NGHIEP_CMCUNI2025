from sqlalchemy import Column, BigInteger, String, DECIMAL, Enum, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base
import enum

class SensorStatus(str, enum.Enum):
    ok = "ok"
    error = "error"
    missing = "missing"

class SensorReadings(Base):
    __tablename__ = "sensor_readings"

    reading_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(BigInteger, ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    metric = Column(String(255), nullable=False)
    value_num = Column(DECIMAL(10, 3))
    unit = Column(String(20))
    status = Column(Enum(SensorStatus), default=SensorStatus.ok)
    recorded_at = Column(TIMESTAMP, server_default=func.now())
