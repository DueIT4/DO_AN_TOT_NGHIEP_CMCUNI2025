from sqlalchemy import (
    Column, BigInteger, String, Boolean, Enum, TIMESTAMP, ForeignKey, Integer, DateTime
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.core.db import Base
import enum

# ----- ENUMs -----
class UserStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"

class RoleType(str, enum.Enum):
    support = "support"
    viewer = "viewer"
    admin = "admin"
    support_admin = "support_admin"

class Provider(str, enum.Enum):
    gg = "gg"
    fb = "fb"
    sđt = "sđt"   # giữ nguyên theo schema

# ----- TABLES -----
class Users(Base):
    __tablename__ = "users"
    user_id       = Column(BigInteger, primary_key=True, autoincrement=True)
    username      = Column(String(191), unique=True)
    email         = Column(String(255), unique=True)
    phone         = Column(String(30), unique=True)
    avt_url       = Column(String(500))
    address       = Column(String(500))
    status        = Column(Enum(UserStatus), default=UserStatus.active, nullable=False)
    password      = Column(String(255))           # hashed
    failed_login  = Column(Integer, default=0)
    locked        = Column(DateTime, nullable=True)
    created_at    = Column(TIMESTAMP, server_default=func.now())
    updated_at    = Column(TIMESTAMP, server_default=func.now(), onupdate=func.now())

    roles = relationship("UserRole", back_populates="user", cascade="all, delete-orphan")
    settings = relationship("UserSettings", back_populates="user", uselist=False, cascade="all, delete-orphan")


class Role(Base):
    __tablename__ = "role"
    role_id     = Column(BigInteger, primary_key=True, autoincrement=True)
    role_type   = Column(Enum(RoleType), nullable=False)
    name        = Column(String(255), unique=True, nullable=False)
    description = Column(String(255))

    users = relationship("UserRole", back_populates="role", cascade="all, delete-orphan")


class UserRole(Base):
    __tablename__ = "user_role"
    user_role_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id      = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    role_id      = Column(BigInteger, ForeignKey("role.role_id", ondelete="CASCADE"), nullable=False)
    assigned_at  = Column(TIMESTAMP, server_default=func.now())

    user = relationship("Users", back_populates="roles")
    role = relationship("Role",  back_populates="users")


class AuthAccounts(Base):
    __tablename__ = "auth_accounts"
    auth_id          = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id          = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    provider         = Column(Enum(Provider), nullable=False)
    provider_user_id = Column(String(255))
    phone_verified   = Column(Boolean, default=False)
    created_at       = Column(TIMESTAMP, server_default=func.now())

    user = relationship("Users")


class UserSettings(Base):
    __tablename__ = "user_settings"
    user_setting_id      = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id              = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False, unique=True)
    color                = Column(String(255))
    font_size            = Column(String(255))
    language             = Column(String(255))
    notification_enabled = Column(Boolean, default=True)
    auto_connect         = Column(Boolean, default=False)
    share_data_with_ai   = Column(Boolean, default=True)

    user = relationship("Users", back_populates="settings")
