# backend/app/models/img.py
from sqlalchemy import Column, BigInteger, String, Enum, ForeignKey, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base
import enum

class SourceType(str, enum.Enum):
    camera = "camera"
    upload = "upload"

class Img(Base):
    __tablename__ = "img"

    img_id = Column(BigInteger, primary_key=True, autoincrement=True)
    source_type = Column(Enum(SourceType), nullable=False)
    device_id = Column(BigInteger, ForeignKey("devices.device_id", ondelete="SET NULL"))
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"))
    file_url = Column(String(700), nullable=False)
    created_at = Column(TIMESTAMP, server_default=func.now())
