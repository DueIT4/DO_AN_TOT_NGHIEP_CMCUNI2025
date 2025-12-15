from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime


class NotificationCreate(BaseModel):
    title: str = Field(..., max_length=255)
    description: str
    user_ids: Optional[List[int]] = None   # danh sách người nhận
    send_all: bool = False                 # hoặc gửi tất cả


# ✅ THÊM MỚI: schema cho resend
class NotificationResend(BaseModel):
    user_ids: Optional[List[int]] = None
    send_all: bool = False


class NotificationOut(BaseModel):
    notification_id: int
    user_id: int
    title: str
    description: str
    created_at: datetime
    read_at: Optional[datetime] = None

    # ✅ THÊM để khớp endpoint /me và tracking resend
    sender_id: Optional[int] = None
    sender_name: Optional[str] = None
    resend_of: Optional[int] = None

    class Config:
        from_attributes = True


# Dùng cho trang “đã gửi”: có kèm tên/email người nhận
class NotificationWithUser(NotificationOut):
    username: Optional[str] = None
    email: Optional[str] = None
