from sqlalchemy import Column, BigInteger, String, Enum, Integer, DateTime, ForeignKey
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum

class UserStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"

class Users(Base):
    __tablename__ = "users"

    user_id = Column(BigInteger, primary_key=True, autoincrement=True)
    role_id = Column(BigInteger, ForeignKey("role.role_id"), nullable=False)
    username = Column(String(191), unique=True, nullable=True)
    email = Column(String(255), unique=True, nullable=True)
    phone = Column(String(30), unique=True, nullable=True)
    avt_url = Column(String(500), nullable=True)
    address = Column(String(500), nullable=True)
    status = Column(Enum(UserStatus), default=UserStatus.active, nullable=False)
    password = Column(String(255), nullable=True)  # có thể null nếu đăng ký qua google/fb
    failed_login = Column(Integer, default=0, nullable=False)
    locked = Column(DateTime, nullable=True)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    updated_at = Column(DateTime, onupdate=func.now(), nullable=True)

    # quan hệ
    auth_links = relationship("AuthAccount", back_populates="user", cascade="all, delete-orphan")
    # Liên kết với bảng role (1 role / user)
    role = relationship("Role", back_populates="users")
    #role = relationship("Role", backref="users")
