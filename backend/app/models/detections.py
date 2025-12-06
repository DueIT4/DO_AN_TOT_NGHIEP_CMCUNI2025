from sqlalchemy import (
    Column, BigInteger, String, Text, DateTime, ForeignKey,
    Numeric, JSON, Enum
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Diseases(Base):
    __tablename__ = "diseases"

    disease_id = Column(BigInteger, primary_key=True, autoincrement=True)
    name = Column(String(255), unique=True)
    description = Column(Text)
    treatment_guideline = Column(Text)
    created_at = Column(DateTime, server_default=func.now())

    detections = relationship("Detection", back_populates="disease")
    

class Detection(Base):
    __tablename__ = "detections"

    detection_id = Column(BigInteger, primary_key=True, autoincrement=True)
    img_id = Column(BigInteger, ForeignKey("img.img_id"), nullable=False)
    disease_id = Column(BigInteger, ForeignKey("diseases.disease_id"), nullable=True)
    confidence = Column(Numeric(5, 2))
    description = Column(Text)
    treatment_guideline = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    bbox = Column(JSON)
    review_status = Column(
        Enum("pending", "approved", "rejected", name="review_status"),
        nullable=False,
        default="pending"
    )
    model_version = Column(String(255))

    img = relationship("Img", back_populates="detections")
    disease = relationship("Diseases", back_populates="detections")
