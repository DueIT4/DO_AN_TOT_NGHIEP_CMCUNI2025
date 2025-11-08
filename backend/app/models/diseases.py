from sqlalchemy import Column, BigInteger, String, Text, TIMESTAMP
from sqlalchemy.sql import func
from app.core.db import Base

class Disease(Base):
    __tablename__ = "diseases"

    disease_id = Column(BigInteger, primary_key=True, autoincrement=True)
    name = Column(String(255), unique=True)
    description = Column(Text)
    treatment_guideline = Column(Text)
    created_at = Column(TIMESTAMP, server_default=func.now())
