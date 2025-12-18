# app/models/image_detection.py
import enum

from sqlalchemy import (
    Column,
    BigInteger,
    String,
    Text,
    ForeignKey,
    DateTime,
    Numeric,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base



# =========================
# 1) ENUM Python (mapping với ENUM trong MySQL)
# =========================

class SourceType(str, enum.Enum):
    camera = "camera"
    upload = "upload"


class ReviewStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


# =========================
# 2) BẢNG img
# =========================
class Img(Base):
    __tablename__ = "img"

    img_id = Column(BigInteger, primary_key=True, autoincrement=True)

    # ✅ Postgres: lưu string thay vì SAEnum
    source_type = Column(String(20), nullable=False)  # 'camera' | 'upload'

    device_id = Column(BigInteger, ForeignKey("devices.device_id", ondelete="SET NULL"), nullable=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    file_url = Column(String(700), nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    user = relationship("Users", back_populates="images", foreign_keys=[user_id], lazy="joined")
    device = relationship("Device", back_populates="images", foreign_keys=[device_id])

    detections = relationship(
        "Detection",
        back_populates="img",
        cascade="all, delete-orphan",
    )


# =========================
# 3) BẢNG diseases
# =========================

class Disease(Base):
    __tablename__ = "diseases"

    disease_id = Column(BigInteger, primary_key=True, autoincrement=True)
    name = Column(String(255), unique=True, nullable=True)
    description = Column(Text, nullable=True)
    treatment_guideline = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    # 1 bệnh → nhiều detection
    detections = relationship(
        "Detection",
        back_populates="disease",
    )


# =========================
# 4) BẢNG detections
# =========================
class Detection(Base):
    __tablename__ = "detections"

    detection_id = Column(BigInteger, primary_key=True, autoincrement=True)
    img_id = Column(BigInteger, ForeignKey("img.img_id", ondelete="CASCADE"), nullable=False)
    disease_id = Column(BigInteger, ForeignKey("diseases.disease_id", ondelete="SET NULL"), nullable=True)

    confidence = Column(Numeric(5, 2), nullable=True)
    description = Column(Text, nullable=True)
    treatment_guideline = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    # ✅ Postgres JSONB (tốt hơn JSON cho query/index)
    bbox = Column(JSONB, nullable=True)

    # ✅ Postgres: lưu string thay vì SAEnum để tránh CREATE TYPE
    review_status = Column(String(20), nullable=False, default="pending")  # pending/approved/rejected

    model_version = Column(String(255), nullable=True)

    img = relationship("Img", back_populates="detections")
    disease = relationship("Disease", back_populates="detections")
