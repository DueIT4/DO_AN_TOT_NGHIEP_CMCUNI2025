# app/models/user.py
import enum

from sqlalchemy import (
    Column,
    BigInteger,
    String,
    Enum as SAEnum,
    DateTime,
    Integer,
    ForeignKey,
)
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship

from app.core.database import Base
from app.models.role import RoleType  # 👈 THÊM DÒNG NÀY (nếu chưa có)


class UserStatus(str, enum.Enum):
    active = "active"
    inactive = "inactive"


class Users(Base):
    __tablename__ = "users"

    user_id = Column(BigInteger, primary_key=True, autoincrement=True)
    role_id = Column(BigInteger, ForeignKey("role.role_id"), nullable=False)

    username = Column(String(191), unique=True)
    email = Column(String(255), unique=True)
    phone = Column(String(30), unique=True)

    avt_url = Column(String(500))
    address = Column(String(500))

    status = Column(SAEnum(UserStatus), default=UserStatus.active)
    password = Column(String(255))
    failed_login = Column(Integer, default=0)
    locked = Column(DateTime, nullable=True)

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    # ------- QUAN HỆ -------
    role = relationship("Role", back_populates="users")
    devices = relationship("Device", back_populates="user")
    images = relationship("Img", back_populates="user")

    notifications = relationship(
        "Notifications",
        back_populates="user",
        foreign_keys="Notifications.user_id",
        cascade="all, delete-orphan",
    )

    notifications_sent = relationship(
        "Notifications",
        back_populates="sender",
        foreign_keys="Notifications.sender_id",
    )

    support_tickets = relationship("SupportTicket", back_populates="user")
    support_messages = relationship("SupportMessage", back_populates="sender")
    user_settings = relationship("UserSettings", back_populates="user", uselist=False)
    chatbot = relationship("Chatbot", back_populates="user")
    auth_accounts = relationship("AuthAccount", back_populates="user")

    # 👇 THÊM PROPERTY NÀY
    @property
    def role_type(self) -> RoleType | None:
        """
        Trả về Enum RoleType của user (admin, support, viewer, support_admin)
        Dựa trên quan hệ self.role.role_type
        """
        if not self.role:
            return None
        return self.role.role_type
        # nếu muốn trả string thay vì Enum -> return self.role.role_type.value
