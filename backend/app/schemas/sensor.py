# app/schemas/sensors.py
from datetime import datetime
from pydantic import BaseModel
from typing import Optional


class SensorInput(BaseModel):
    device_id: int
    metric: str
    value_num: float
    unit: str


class DeviceLogOut(BaseModel):
    log_id: int
    event_type: str
    description: Optional[str]
    created_at: datetime

    class Config:
        orm_mode = True
