from sqlalchemy import Column, BigInteger, String, Enum, Boolean, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum

class Provider(str, enum.Enum):
    gg = "gg"
    fb = "fb"
    sdt = "sdt"  # đăng ký bằng số điện thoại

class AuthAccount(Base):
    __tablename__ = "auth_accounts"

    auth_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    provider = Column(Enum(Provider), nullable=False)  # gg/fb/sdt
    provider_user_id = Column(String(255), nullable=True)  # id bên gg/fb/hoặc chính phone
    phone_verified = Column(Boolean, default=False, nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    user = relationship("Users", back_populates="auth_links")
