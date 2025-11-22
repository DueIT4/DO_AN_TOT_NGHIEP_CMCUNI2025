# app/api/v1/routes_users_devices.py
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, func, desc

from app.core.database import get_db
from app.models.user import Users
from app.models.devices import Device
from app.models.sensor_readings import SensorReadings
from app.schemas.users_devices import (
    UserOut,
    DeviceListItem,
    DeviceDetailOut,
    SensorReadingOut,
)


router = APIRouter(tags=["Users & Devices (Admin)"])

# 1) Danh sách user (cho FE hiển thị list)
@router.get("/users", response_model=List[UserOut])
def list_users(
    db: Session = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
):
    users = db.scalars(
        select(Users)
        .order_by(Users.created_at.desc())
        .offset(skip)
        .limit(limit)
    ).all()
    return users


# 2) Lấy danh sách thiết bị của 1 user
@router.get("/users/{user_id}/devices", response_model=List[DeviceListItem])
def list_user_devices(user_id: int, db: Session = Depends(get_db)):
    user = db.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User không tồn tại")

    devices = db.scalars(
        select(Device)
        .where(Device.user_id == user_id)
        .order_by(Device.created_at.desc())
    ).all()

    result: List[DeviceListItem] = []
    for d in devices:
        result.append(
            DeviceListItem(
                device_id=d.device_id,
                name=d.name,
                serial_no=d.serial_no,
                location=d.location,
                status=d.status,
                device_type_id=d.device_type_id,
                device_type_name=d.device_type.device_type_name if d.device_type else None,
                stream_url=d.stream_url,
            )
        )
    return result


# 3) Chi tiết 1 thiết bị (kèm owner + last sensor reading)
@router.get("/devices/{device_id}", response_model=DeviceDetailOut)
def get_device_detail(device_id: int, db: Session = Depends(get_db)):
    device: Device | None = db.get(Device, device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Thiết bị không tồn tại")

    # Lấy sensor reading mới nhất
    last_sr: SensorReadings | None = (
        db.query(SensorReadings)
        .filter(SensorReadings.device_id == device_id)
        .order_by(SensorReadings.recorded_at.desc())
        .first()
    )

    last_sr_out = None
    if last_sr:
        last_sr_out = SensorReadingOut.from_orm(last_sr)

    # Owner
    owner = device.user

    return DeviceDetailOut(
        device_id=device.device_id,
        name=device.name,
        serial_no=device.serial_no,
        location=device.location,
        status=device.status,
        stream_url=device.stream_url,
        device_type_id=device.device_type_id,
        device_type_name=device.device_type.device_type_name if device.device_type else None,
        owner_id=owner.user_id if owner else None,
        owner_username=owner.username if owner else None,
        last_sensor_reading=last_sr_out,
    )
