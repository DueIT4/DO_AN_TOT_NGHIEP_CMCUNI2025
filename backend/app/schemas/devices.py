# app/schemas/devices.py
from pydantic import BaseModel
from typing import Optional

class DeviceCreate(BaseModel):
    name: str
    device_type_id: int
    serial_no: str
    location: Optional[str] = None

class DeviceResp(BaseModel):
    device_id: int
    name: str
    device_type_id: int
    serial_no: str
    location: Optional[str]
    status: str

    class Config:
        orm_mode = True
