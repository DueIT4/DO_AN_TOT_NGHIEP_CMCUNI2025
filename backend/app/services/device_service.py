from __future__ import annotations
from typing import Optional
from sqlalchemy.orm import Session
from app.models.devices import Devices
from app.models.device_type import DeviceType
from app.models.device_logs import DeviceLogs
from app.services.common import get_or_404, commit_refresh, paginate, NotFoundError

# ---------- Device Type ----------
def create_device_type(db: Session, name: str, has_stream: bool = False, status: str = "active") -> DeviceType:
    dt = DeviceType(device_type_name=name, has_stream=has_stream, status=status)
    return commit_refresh(db, dt)

def list_device_types(db: Session):
    return db.query(DeviceType).order_by(DeviceType.device_type_name.asc()).all()

# ---------- Device ----------
def create_device(
    db: Session,
    *,
    device_type_id: int,
    name: Optional[str] = None,
    serial_no: Optional[str] = None,
    location: Optional[str] = None,
    status: str = "active",
    parent_device_id: Optional[int] = None,
    user_id: Optional[int] = None,
    stream_url: Optional[str] = None,
) -> Devices:
    # ensure type exists
    get_or_404(db, DeviceType, device_type_id)
    if parent_device_id:
        get_or_404(db, Devices, parent_device_id)
    dev = Devices(
        user_id=user_id,
        name=name,
        device_type_id=device_type_id,
        parent_device_id=parent_device_id,
        serial_no=serial_no,
        location=location,
        status=status,
        stream_url=stream_url,
    )
    return commit_refresh(db, dev)

def update_device(db: Session, device_id: int, **fields) -> Devices:
    dev = get_or_404(db, Devices, device_id)
    for k, v in fields.items():
        if v is not None and hasattr(dev, k):
            setattr(dev, k, v)
    return commit_refresh(db, dev)

def list_devices(db: Session, page: int = 1, size: int = 20):
    q = db.query(Devices).order_by(Devices.created_at.desc())
    return paginate(q, page, size)

def add_device_log(db: Session, device_id: int, event_type: str, description: str) -> DeviceLogs:
    get_or_404(db, Devices, device_id)
    log = DeviceLogs(device_id=device_id, event_type=event_type, description=description)
    return commit_refresh(db, log)
