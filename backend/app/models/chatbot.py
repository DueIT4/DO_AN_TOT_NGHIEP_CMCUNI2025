from sqlalchemy import Column, BigInteger, String, Text, DateTime, ForeignKey, Enum
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from app.core.database import Base


class Chatbot(Base):
    __tablename__ = "chatbot"

    chatbot_id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.user_id"), nullable=False)

    created_at = Column(DateTime, server_default=func.now())
    end_at = Column(DateTime, nullable=True)
    status = Column(Enum("active", "ended", name="chatbot_status"), default="active")

    user = relationship("Users", back_populates="chatbots")
    details = relationship("ChatbotDetail", back_populates="chatbot")


class ChatbotDetail(Base):
    __tablename__ = "chatbot_detail"

    detail_id = Column(BigInteger, primary_key=True, autoincrement=True)
    chatbot_id = Column(BigInteger, ForeignKey("chatbot.chatbot_id"), nullable=False)
    question = Column(Text)
    answer = Column(Text)
    created_at = Column(DateTime, server_default=func.now())

    chatbot = relationship("Chatbot", back_populates="details")
