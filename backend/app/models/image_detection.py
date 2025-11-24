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
    Enum as SAEnum,
)
from sqlalchemy.dialects.mysql import JSON
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base  # 🔥 dùng chung 1 Base cho toàn project


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
#   Khớp với:
#   CREATE TABLE img (
#     img_id      BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
#     source_type ENUM('camera','upload') NOT NULL,
#     device_id   BIGINT UNSIGNED NULL,
#     user_id     BIGINT UNSIGNED NULL,
#     file_url    VARCHAR(700) NOT NULL,
#     created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
#     ...
#   )
# =========================

class Img(Base):
    __tablename__ = "img"

    img_id = Column(BigInteger, primary_key=True, autoincrement=True)
    source_type = Column(SAEnum(SourceType), nullable=False)
    device_id = Column(BigInteger, ForeignKey("devices.device_id", ondelete="SET NULL"), nullable=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="SET NULL"), nullable=True)
    file_url = Column(String(700), nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    # Quan hệ ngược
    user = relationship("Users", back_populates="images", foreign_keys=[user_id], lazy="joined")
    device = relationship("Device", back_populates="images", foreign_keys=[device_id])

    # 1 ảnh có nhiều detection
    detections = relationship(
        "Detection",
        back_populates="img",
        cascade="all, delete-orphan",
    )


# =========================
# 3) BẢNG diseases
#   Khớp với:
#   CREATE TABLE diseases (
#     disease_id BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
#     name VARCHAR(255) UNIQUE,
#     description TEXT,
#     treatment_guideline TEXT,
#     created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
#   )
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
#   Khớp với:
#   CREATE TABLE detections (
#     detection_id        BIGINT UNSIGNED PRIMARY KEY AUTO_INCREMENT,
#     img_id              BIGINT UNSIGNED NOT NULL,
#     disease_id          BIGINT UNSIGNED NULL,
#     confidence          DECIMAL(5,2),
#     description         TEXT,
#     treatment_guideline TEXT,
#     created_at          TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
#     bbox                JSON,
#     review_status       ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
#     model_version       VARCHAR(255),
#     ...
#   )
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

    bbox = Column(JSON, nullable=True)
    review_status = Column(SAEnum(ReviewStatus), nullable=False, default=ReviewStatus.pending)
    model_version = Column(String(255), nullable=True)

    # Quan hệ
    img = relationship("Img", back_populates="detections")
    disease = relationship("Disease", back_populates="detections")
