# app/schemas/users_devices.py
from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel

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

    class Config:
        orm_mode = True


class SensorReadingOut(BaseModel):
    reading_id: int
    metric: str
    value_num: Optional[float]
    unit: Optional[str]
    status: str
    recorded_at: datetime

    class Config:
        orm_mode = True


class DeviceDetailOut(BaseModel):
    device_id: int
    name: Optional[str]
    serial_no: Optional[str]
    location: Optional[str]
    status: str
    stream_url: Optional[str]

    device_type_id: int
    device_type_name: Optional[str]

    owner_id: Optional[int]
    owner_username: Optional[str]

    last_sensor_reading: Optional[SensorReadingOut] = None

    class Config:
        orm_mode = True


class DetectionHistoryItem(BaseModel):
    detection_id: int
    img_id: int
    file_url: str
    disease_name: Optional[str]
    confidence: Optional[float]
    created_at: datetime

    class Config:
        orm_mode = True


class DetectionHistoryList(BaseModel):
    items: List[DetectionHistoryItem]
    total: int
