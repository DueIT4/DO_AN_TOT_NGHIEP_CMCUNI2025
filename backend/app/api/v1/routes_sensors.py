from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.models.sensor_readings import SensorReadings
from datetime import datetime
from pydantic import BaseModel

router = APIRouter(prefix="/sensors", tags=["Sensors"])

class SensorInput(BaseModel):
    device_id: int
    metric: str
    value_num: float
    unit: str

@router.post("/")
def add_reading(data: SensorInput, db: Session = Depends(get_db)):
    reading = SensorReadings(**data.dict(), recorded_at=datetime.utcnow())
    db.add(reading)
    db.commit()
    return {"message": "Đã ghi dữ liệu cảm biến"}

@router.get("/{device_id}")
def list_readings(device_id: int, db: Session = Depends(get_db)):
    return db.query(SensorReadings).filter(SensorReadings.device_id == device_id).order_by(SensorReadings.recorded_at.desc()).limit(50).all()
