# app/api/v1/routes_devices.py
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.devices import DeviceCreate, DeviceUpdate, DeviceOut
from app.services.device_service import devices_service as svc
from app.api.v1.deps import get_current_user   # BẮT BUỘC token để vào

router = APIRouter(prefix="/devices", tags=["Device"])


# =============================
# 1) GET toàn bộ device (public hoặc bạn có thể yêu cầu token)
# =============================
@router.get("/", response_model=List[DeviceOut])
def list_devices(db: Session = Depends(get_db)):
    devices = svc.list_devices(db)
    return [DeviceOut.from_orm(d) for d in devices]


# =============================
# 2) GET chi tiết device (public)
# =============================
@router.get("/{device_id}", response_model=DeviceOut)
def get_device(device_id: int, db: Session = Depends(get_db)):
    d = svc.get_device(db, device_id)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)


# =============================
# 3) CREATE device (BẮT BUỘC token)
# =============================
@router.post(
    "/",
    response_model=DeviceOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(get_current_user)]   # token bắt buộc
)
def create_device(
    body: DeviceCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    d = svc.create_device(db, body, user_id=current_user.user_id)
    return DeviceOut.from_orm(d)


# =============================
# 4) UPDATE device (BẮT BUỘC token)
# =============================
@router.put(
    "/{device_id}",
    response_model=DeviceOut,
    dependencies=[Depends(get_current_user)]
)
def update_device(
    device_id: int,
    body: DeviceUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    d = svc.update_device(db, device_id, body)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)


# =============================
# 5) DELETE device (BẮT BUỘC token)
# =============================
@router.delete(
    "/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(get_current_user)]
)
def delete_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user)
):
    ok = svc.delete_device(db, device_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return
