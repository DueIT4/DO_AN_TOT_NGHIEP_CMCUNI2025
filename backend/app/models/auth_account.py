import enum
from sqlalchemy import (
    Column, BigInteger, String, Enum, Boolean, DateTime, ForeignKey
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class Provider(str, enum.Enum):
    gg = "gg"
    fb = "fb"
    sdt = "sdt"


class AuthAccount(Base):
    __tablename__ = "auth_accounts"

    auth_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id"), nullable=False)

    provider = Column(Enum(Provider), nullable=False)
    provider_user_id = Column(String(255))
    phone_verified = Column(Boolean, default=False)

    created_at = Column(DateTime, server_default=func.now())

    user = relationship("Users", back_populates="auth_accounts")
