from sqlalchemy import (
    Column, BigInteger, DECIMAL, ForeignKey, Enum, JSON, String, Text, TIMESTAMP
)
from sqlalchemy.sql import func
from app.core.db import Base
import enum


class ReviewStatus(str, enum.Enum):
    pending = "pending"
    approved = "approved"
    rejected = "rejected"


class Detection(Base):
    __tablename__ = "detections"

    detection_id = Column(BigInteger, primary_key=True, autoincrement=True)
    img_id = Column(BigInteger, ForeignKey("img.img_id", ondelete="CASCADE"), nullable=False)
    disease_id = Column(BigInteger, ForeignKey("diseases.disease_id", ondelete="SET NULL"))
    confidence = Column(DECIMAL(5, 2))
    description = Column(Text)
    treatment_guideline = Column(Text)
    bbox = Column(JSON)
    review_status = Column(Enum(ReviewStatus), default=ReviewStatus.pending)
    model_version = Column(String(255))
    created_at = Column(TIMESTAMP, server_default=func.now())
