# app/api/v1/routes_device_logs.py
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.core.database import get_db
from app.models.devices import Device
from app.models.device_logs import DeviceLogs
from app.schemas.sensor import DeviceLogOut

router = APIRouter(tags=["Device Logs"])


@router.get("/{device_id}/logs", response_model=list[DeviceLogOut])
def list_device_logs(
    device_id: int,
    db: Session = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
):
    device = db.get(Device, device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Thiết bị không tồn tại")

    logs = (
        db.query(DeviceLogs)
        .filter(DeviceLogs.device_id == device_id)
        .order_by(desc(DeviceLogs.created_at))
        .offset(skip)
        .limit(limit)
        .all()
    )
    return logs
