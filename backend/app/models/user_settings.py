from sqlalchemy import Column, BigInteger, String, Boolean, ForeignKey
from sqlalchemy.orm import relationship
from app.core.database import Base


class UserSettings(Base):
    __tablename__ = "user_settings"

    user_setting_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id"), nullable=False, unique=True)

    color = Column(String(255))
    font_size = Column(String(255))
    language = Column(String(255))
    notification_enabled = Column(Boolean, default=True)
    auto_connect = Column(Boolean, default=False)
    share_data_with_ai = Column(Boolean, default=True)

    user = relationship("Users", back_populates="user_settings")
