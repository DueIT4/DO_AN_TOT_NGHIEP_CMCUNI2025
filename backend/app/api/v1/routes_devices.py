from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.schemas.devices import DeviceCreate, DeviceUpdate, DeviceOut
from app.services.device_service import devices_service as svc
from app.api.v1.deps import get_current_user
from app.models.role import RoleType  # 👈 dùng Enum

router = APIRouter(prefix="/devices", tags=["Device"])


@router.get("/", response_model=List[DeviceOut])
def list_devices(db: Session = Depends(get_db)):
    devices = svc.list_devices(db)
    return [DeviceOut.from_orm(d) for d in devices]


@router.get("/{device_id}", response_model=DeviceOut)
def get_device(device_id: int, db: Session = Depends(get_db)):
    d = svc.get_device(db, device_id)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)


@router.post(
    "/",
    response_model=DeviceOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(get_current_user)],
)
def create_device(
    body: DeviceCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    - User thường: luôn gán device cho chính mình.
    - Admin / support_admin: nếu body.user_id != current_user.user_id
      thì được phép gán thiết bị cho user khác.
    """
    # Nếu FE không gửi user_id -> gán cho chính current_user
    target_user_id = body.user_id or current_user.user_id

    # Nếu FE gửi user_id khác mình → chỉ cho phép nếu là admin / support_admin
    if body.user_id and body.user_id != current_user.user_id:
        if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Chỉ admin mới được gán thiết bị cho người dùng khác",
            )

    d = svc.create_device(db, body, user_id=target_user_id)
    return DeviceOut.from_orm(d)


@router.put(
    "/{device_id}",
    response_model=DeviceOut,
    dependencies=[Depends(get_current_user)],
)
def update_device(
    device_id: int,
    body: DeviceUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    d = svc.update_device(db, device_id, body)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)


@router.delete(
    "/{device_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(get_current_user)],
)
def delete_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    ok = svc.delete_device(db, device_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return
