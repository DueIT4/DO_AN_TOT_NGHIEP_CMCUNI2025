from sqlalchemy import Column, BigInteger, String, Enum, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum

class RoleType(str, enum.Enum):
    support = "support"
    viewer = "viewer"
    admin = "admin"
    support_admin = "support_admin"

class Role(Base):
    __tablename__ = "role"

    role_id = Column(BigInteger, primary_key=True, autoincrement=True)
    role_type = Column(Enum(RoleType), nullable=False, unique=True)  # unique để đảm bảo mỗi loại 1 dòng
    description = Column(String(255), nullable=True)
    # Quan hệ ngược (tuỳ chọn)
    users = relationship("Users", back_populates="role")



