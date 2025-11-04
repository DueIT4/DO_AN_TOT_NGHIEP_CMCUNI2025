from sqlalchemy import Column, BigInteger, ForeignKey, Enum, Text, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base
import enum

class EventType(str, enum.Enum):
    online = "online"
    offline = "offline"
    error = "error"
    maintenance = "maintenance"

class DeviceLogs(Base):
    __tablename__ = "device_logs"

    log_id = Column(BigInteger, primary_key=True, autoincrement=True)
    device_id = Column(BigInteger, ForeignKey("devices.device_id", ondelete="CASCADE"), nullable=False)
    event_type = Column(Enum(EventType), nullable=False)
    description = Column(Text)
    created_at = Column(TIMESTAMP, server_default=func.now())
