# app/models/password_reset.py
from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime
from app.core.database import Base

class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otp"

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, nullable=False)
    contact = Column(String(255), nullable=False)  # email hoặc sdt
    otp_code = Column(String(6), nullable=False)
    expires_at = Column(DateTime, nullable=False)
    attempts = Column(Integer, default=0)
    created_at = Column(DateTime, default=datetime.utcnow)
