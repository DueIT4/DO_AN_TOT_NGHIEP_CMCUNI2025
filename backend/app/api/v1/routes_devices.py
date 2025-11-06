from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.db import get_db
from app.schemas.devices import DeviceCreate, DeviceUpdate, DeviceOut
from app.services.device_service import devices_service as svc

router = APIRouter(prefix="/devices", tags=["Devices"])

@router.get("/", response_model=List[DeviceOut])
def list_devices(db: Session = Depends(get_db)):
    return [DeviceOut.from_orm(d) for d in svc.list_devices(db)]

@router.get("/{device_id}", response_model=DeviceOut)
def get_device(device_id: int, db: Session = Depends(get_db)):
    d = svc.get_device(db, device_id)
    if not d: raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)

@router.post("/", response_model=DeviceOut, status_code=status.HTTP_201_CREATED)
def create_device(body: DeviceCreate, db: Session = Depends(get_db)):
    try:
        d = svc.create_device(db, body)
        return DeviceOut.from_orm(d)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{device_id}", response_model=DeviceOut)
def update_device(device_id: int, body: DeviceUpdate, db: Session = Depends(get_db)):
    try:
        d = svc.update_device(db, device_id, body)
        return DeviceOut.from_orm(d)
    except LookupError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_device(device_id: int, db: Session = Depends(get_db)):
    try:
        svc.delete_device(db, device_id)
        return
    except LookupError as e:
        raise HTTPException(status_code=404, detail=str(e))
