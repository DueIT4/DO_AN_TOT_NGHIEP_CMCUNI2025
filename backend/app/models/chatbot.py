from sqlalchemy import Column, BigInteger, Text, Enum, ForeignKey, DateTime
from sqlalchemy.sql import func
from sqlalchemy.orm import relationship
from app.db.base import Base
import enum

class ChatbotStatus(str, enum.Enum):
    active = "active"
    ended = "ended"

class Chatbot(Base):
    __tablename__ = "chatbot"

    chatbot_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)
    end_at = Column(DateTime, nullable=True)
    status = Column(Enum(ChatbotStatus), nullable=False, default=ChatbotStatus.active)

    user = relationship("Users", backref="chatbots")
    details = relationship("ChatbotDetail", cascade="all, delete-orphan", backref="chatbot", order_by="ChatbotDetail.created_at")

class ChatbotDetail(Base):
    __tablename__ = "chatbot_detail"

    detail_id = Column(BigInteger, primary_key=True, autoincrement=True)
    chatbot_id = Column(BigInteger, ForeignKey("chatbot.chatbot_id", ondelete="CASCADE"), nullable=False)
    question = Column(Text, nullable=False)
    answer = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now(), nullable=False)

