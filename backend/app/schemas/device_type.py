from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field
from pydantic import ConfigDict


class DeviceTypeBase(BaseModel):
    device_type_name: str = Field(..., min_length=1, max_length=255)
    has_stream: bool = False
    status: str = "active"   # 'active' | 'inactive'


class DeviceTypeCreate(DeviceTypeBase):
    pass


class DeviceTypeUpdate(BaseModel):
    device_type_name: Optional[str] = Field(None, min_length=1, max_length=255)
    has_stream: Optional[bool] = None
    status: Optional[str] = None   # 'active' | 'inactive'


class DeviceTypeOut(BaseModel):
    device_type_id: int
    device_type_name: str
    has_stream: bool
    status: str
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)
