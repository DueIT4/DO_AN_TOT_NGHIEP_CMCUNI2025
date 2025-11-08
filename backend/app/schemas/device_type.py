from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.models.device_type import DeviceStatus

class DeviceTypeOut(BaseModel):
    device_type_id: int
    device_type_name: str
    has_stream: bool
    status: DeviceStatus
    created_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

class DeviceTypeCreate(BaseModel):
    device_type_name: str
    has_stream: bool = False
    status: DeviceStatus = DeviceStatus.active

class DeviceTypeUpdate(BaseModel):
    device_type_name: Optional[str] = None
    has_stream: Optional[bool] = None
    status: Optional[DeviceStatus] = None

