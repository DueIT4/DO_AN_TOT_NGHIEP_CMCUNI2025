import enum
from sqlalchemy import Column, BigInteger, String, Enum
from sqlalchemy.orm import relationship
from app.core.database import Base


class RoleType(str, enum.Enum):
    support = "support"
    viewer = "viewer"
    admin = "admin"
    support_admin = "support_admin"


class Role(Base):
    __tablename__ = "role"

    role_id = Column(BigInteger, primary_key=True, autoincrement=True)
    role_type = Column(Enum(RoleType), nullable=False)
    description = Column(String(255))

    users = relationship("Users", back_populates="role")


