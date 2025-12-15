from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum

class ChatbotStatus(str, Enum):
    active = "active"
    ended = "ended"

# ----- Chatbot Sessions -----
class ChatbotCreate(BaseModel):
    """Tạo session chatbot mới"""
    pass  # Không cần input, tự động tạo từ user_id

class ChatbotOut(BaseModel):
    chatbot_id: int
    user_id: int
    created_at: datetime
    end_at: Optional[datetime]
    status: ChatbotStatus
    details_count: Optional[int] = 0

    class Config:
        from_attributes = True

# ----- Chatbot Messages -----
class ChatbotMessageCreate(BaseModel):
    """Gửi câu hỏi đến chatbot"""
    chatbot_id: Optional[int] = None  # Nếu None, tự động tạo session mới
    question: str = Field(..., min_length=1)

class ChatbotMessageOut(BaseModel):
    detail_id: int
    chatbot_id: int
    question: str
    answer: str
    created_at: datetime

    class Config:
        from_attributes = True

class ChatbotSessionWithMessages(ChatbotOut):
    """Session kèm danh sách messages"""
    messages: List[ChatbotMessageOut] = []
