# app/schemas/users_devices.py
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr
from app.models.user import UserStatus


class UserOut(BaseModel):
    user_id: int
    username: Optional[str]
    email: Optional[str]
    phone: Optional[str]
    status: UserStatus

    class Config:
        orm_mode = True

class DeviceListItem(BaseModel):
    device_id: int
    name: Optional[str]
    serial_no: Optional[str]
    location: Optional[str]
    status: str
    device_type_id: int
    device_type_name: Optional[str]
    stream_url: Optional[str]
    # Bổ sung:
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    class Config:
        orm_mode = True

class DeviceDetailOut(BaseModel):
    device_id: int
    name: Optional[str]
    serial_no: Optional[str]
    location: Optional[str]
    status: str
    stream_url: Optional[str]
    # Bổ sung:
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    device_type_id: int
    device_type_name: Optional[str]

    owner_id: Optional[int]
    owner_username: Optional[str]


    class Config:
        orm_mode = True
class DetectionHistoryItem(BaseModel):
    detection_id: int
    img_id: int
    file_url: str
    disease_name: Optional[str] = None
    confidence: Optional[float] = None
    created_at: datetime

    user_id: Optional[int] = None
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None


class DetectionHistoryList(BaseModel):
    items: List[DetectionHistoryItem]
    total: int
