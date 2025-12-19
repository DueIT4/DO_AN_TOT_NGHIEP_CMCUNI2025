# app/models/chatbot.py
import enum
from sqlalchemy import Column, BigInteger, ForeignKey, DateTime, Enum as SAEnum, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from app.core.database import Base


class ChatbotStatus(str, enum.Enum):
    active = "active"
    ended = "ended"


class Chatbot(Base):
    __tablename__ = "chatbot"

    chatbot_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(
        BigInteger,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    end_at = Column(DateTime, nullable=True)
    status = Column(SAEnum(ChatbotStatus), default=ChatbotStatus.active, nullable=False)

    # relationship 2 chiều với Users
    user = relationship("Users", back_populates="chatbot")

    # relationship 2 chiều với ChatbotDetail
    details = relationship(
        "ChatbotDetail",
        back_populates="chatbot",
        cascade="all, delete-orphan",
        passive_deletes=True,
    )


class ChatbotDetail(Base):
    __tablename__ = "chatbot_detail"

    detail_id = Column(BigInteger, primary_key=True, autoincrement=True)
    chatbot_id = Column(
        BigInteger,
        ForeignKey("chatbot.chatbot_id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    question = Column(Text, nullable=False)
    answer = Column(Text, nullable=False)

    created_at = Column(DateTime, server_default=func.now(), nullable=False)

    chatbot = relationship("Chatbot", back_populates="details")
