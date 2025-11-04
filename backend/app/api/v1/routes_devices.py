from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.models.devices import Devices
from app.models.device_logs import DeviceLogs
from app.models.device_type import DeviceType
from pydantic import BaseModel
from datetime import datetime

router = APIRouter(prefix="/devices", tags=["Devices"])

# Schemas
class DeviceSchema(BaseModel):
    name: str
    device_type_id: int
    serial_no: str
    location: str | None = None

@router.get("/")
def list_devices(db: Session = Depends(get_db)):
    return db.query(Devices).all()

@router.post("/")
def add_device(data: DeviceSchema, db: Session = Depends(get_db)):
    if db.query(Devices).filter(Devices.serial_no == data.serial_no).first():
        raise HTTPException(status_code=400, detail="Serial đã tồn tại")
    device = Devices(**data.dict())
    db.add(device)
    db.commit()
    db.refresh(device)
    return {"message": "Thêm thiết bị thành công", "device_id": device.device_id}

@router.post("/{device_id}/log")
def add_log(device_id: int, event_type: str, description: str, db: Session = Depends(get_db)):
    if not db.query(Devices).get(device_id):
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    log = DeviceLogs(device_id=device_id, event_type=event_type, description=description, created_at=datetime.utcnow())
    db.add(log)
    db.commit()
    return {"message": "Log đã ghi"}
