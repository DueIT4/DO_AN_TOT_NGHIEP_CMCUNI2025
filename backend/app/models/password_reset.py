# app/models/password_reset.py
from sqlalchemy import Column, BigInteger, String, DateTime, Integer, Index
from datetime import datetime
from app.core.database import Base

class PasswordResetOTP(Base):
    __tablename__ = "password_reset_otp"

    id = Column(Integer, primary_key=True)
    user_id = Column(BigInteger, nullable=False, index=True)
    contact = Column(String(255), nullable=False, index=True)  # email hoặc sdt
    otp_hash = Column(String(255), nullable=False)             # ✅ lưu hash, không lưu otp plain
    expires_at = Column(DateTime, nullable=False)
    attempts = Column(Integer, default=0, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow, nullable=False)

Index("ix_password_reset_contact_user", PasswordResetOTP.contact, PasswordResetOTP.user_id)
