from pydantic import BaseModel
from typing import Optional
from app.models.devices import DeviceState

class DeviceCreate(BaseModel):
    name: str
    device_type_id: int
    serial_no: str
    location: Optional[str] = None

class DeviceUpdate(BaseModel):
    name: Optional[str] = None
    device_type_id: Optional[int] = None
    serial_no: Optional[str] = None
    location: Optional[str] = None
    status: Optional[DeviceState] = None
    stream_url: Optional[str] = None

class DeviceOut(BaseModel):
    device_id: int
    name: Optional[str]
    device_type_id: int
    serial_no: Optional[str]
    location: Optional[str]
    status: Optional[DeviceState]
    stream_url: Optional[str]

    class Config:
        from_attributes = True
