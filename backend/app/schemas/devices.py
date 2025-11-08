from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.models.devices import DeviceState

# Schema cho DeviceType
class DeviceTypeOut(BaseModel):
    device_type_id: int
    device_type_name: str
    has_stream: bool
    status: str
    
    class Config:
        from_attributes = True

# Schema cho tạo mới device
class DeviceCreate(BaseModel):
    name: str
    device_type_id: int
    serial_no: str
    location: Optional[str] = None
    user_id: Optional[int] = None
    parent_device_id: Optional[int] = None
    stream_url: Optional[str] = None

# Schema cho cập nhật device
class DeviceUpdate(BaseModel):
    name: Optional[str] = None
    device_type_id: Optional[int] = None
    serial_no: Optional[str] = None
    location: Optional[str] = None
    status: Optional[DeviceState] = None
    stream_url: Optional[str] = None
    user_id: Optional[int] = None
    parent_device_id: Optional[int] = None

# Schema cho response device (đầy đủ thông tin)
class DeviceOut(BaseModel):
    device_id: int
    user_id: Optional[int]
    name: Optional[str]
    device_type_id: int
    parent_device_id: Optional[int]
    serial_no: Optional[str]
    location: Optional[str]
    status: Optional[DeviceState]
    stream_url: Optional[str]
    created_at: Optional[datetime]
    updated_at: Optional[datetime]
    
    # Thông tin device_type (nested)
    device_type: Optional[DeviceTypeOut] = None
    
    class Config:
        from_attributes = True

# Schema cho pagination response
class DeviceListResponse(BaseModel):
    page: int
    size: int
    total: int
    pages: int
    items: list[DeviceOut]
    
    class Config:
        from_attributes = True
