# app/schemas/devices.py
from typing import Optional
from datetime import datetime
from pydantic import BaseModel, validator
from pydantic import ConfigDict   # 👈 thêm import này


class DeviceBase(BaseModel):
    name: Optional[str] = None
    device_type_id: int
    parent_device_id: Optional[int] = None
    serial_no: Optional[str] = None
    location: Optional[str] = None
    status: Optional[str] = "active"
    stream_url: Optional[str] = None

    # ✅ Chuẩn hóa parent_device_id: nếu = 0 hoặc "0" -> None
    @validator("parent_device_id", pre=True)
    def normalize_parent(cls, v):
        if v in (0, "0", "", None):
            return None
        return v

    # ✅ Không cho device_type_id = 0
    @validator("device_type_id", pre=True)
    def validate_device_type(cls, v):
        if v in (0, "0", None):
            raise ValueError("device_type_id phải là ID hợp lệ (> 0)")
        return v


class DeviceCreate(DeviceBase):
    # vẫn giữ bắt buộc device_type_id
    device_type_id: int

    # 👇 THÊM FIELD NÀY ĐỂ ADMIN GÁN THIẾT BỊ CHO USER KHÁC
    user_id: Optional[int] = None


class DeviceUpdate(BaseModel):
    name: Optional[str] = None
    device_type_id: Optional[int] = None
    parent_device_id: Optional[int] = None
    serial_no: Optional[str] = None
    location: Optional[str] = None
    status: Optional[str] = None
    stream_url: Optional[str] = None

    @validator("parent_device_id", pre=True)
    def normalize_parent(cls, v):
        if v in (0, "0", "", None):
            return None
        return v

class DeviceOut(BaseModel):
    device_id: int
    name: Optional[str] = None
    serial_no: Optional[str] = None
    location: Optional[str] = None
    status: Optional[str] = "active"
    stream_url: Optional[str] = None
    device_type_id: Optional[int] = None
    user_id: Optional[int] = None
    # Quan trọng: Cho phép null nếu DB chưa kịp ghi hoặc dữ liệu cũ
    created_at: Optional[datetime] = None 
    updated_at: Optional[datetime] = None 

    model_config = ConfigDict(from_attributes=True)