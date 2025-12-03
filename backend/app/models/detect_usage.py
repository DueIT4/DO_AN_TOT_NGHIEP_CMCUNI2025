# app/models/detect_usage.py
from sqlalchemy import Column, BigInteger, String, Integer, Date, UniqueConstraint
from app.core.database import Base


class DetectUsage(Base):
    __tablename__ = "detect_usage"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    client_key = Column(String(255), nullable=False)
    date = Column(Date, nullable=False)
    count = Column(Integer, nullable=False, default=0)

    __table_args__ = (
        UniqueConstraint("client_key", "date", name="uq_detect_client_date"),
    )
