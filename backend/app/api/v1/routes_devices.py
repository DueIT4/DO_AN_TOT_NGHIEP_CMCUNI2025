from typing import List, Optional, Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.services.device_service import devices_service as svc
from app.api.v1.deps import get_current_user
from app.schemas.devices import DeviceCreate, DeviceUpdate, DeviceOut
from app.models.role import RoleType

router = APIRouter(prefix="/devices", tags=["devices"])


# =========================
# ✅ USER: list devices of current user
# GET /devices/me?q=
# =========================
@router.get("/my", response_model=List[DeviceOut], dependencies=[Depends(get_current_user)])
def list_my_devices(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    q: Optional[str] = Query(None, min_length=1),
):
    devices = svc.list_devices_of_user(db, user_id=current_user.user_id, q=q)
    return [DeviceOut.from_orm(d) for d in devices]


# =========================
# ✅ USER: get my device detail
# GET /devices/me/{device_id}
# =========================
@router.get("/my/{device_id}", response_model=DeviceOut, dependencies=[Depends(get_current_user)])
def get_my_device(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    d = svc.get_device(db, device_id)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")

    if getattr(d, "user_id", None) != current_user.user_id:
        raise HTTPException(status_code=403, detail="Bạn không có quyền xem thiết bị này")

    return DeviceOut.from_orm(d)


# =========================
# ✅ USER: latest detection for a device
# GET /devices/{device_id}/latest_detection
# =========================
@router.get("/{device_id}/latest_detection", dependencies=[Depends(get_current_user)])
def device_latest_detection(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    d = svc.get_device(db, device_id)
    if not d:
        raise HTTPException(status_code=404, detail="Device not found")

    if getattr(d, "user_id", None) != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not allowed to view this device")

    return svc.get_latest_detection_payload(db, device_id=device_id)


# =========================
# ✅ USER: select camera (save to server)
# POST /devices/select_camera
# =========================
class SelectCameraIn(BaseModel):
    device_id: int


@router.post("/select_camera", dependencies=[Depends(get_current_user)])
def select_camera(
    payload: SelectCameraIn,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    device = svc.get_device(db, payload.device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")

    if getattr(device, "user_id", None) != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not allowed")

    try:
        updated = svc.select_camera_for_user(db, user_id=current_user.user_id, device=device)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return {"selected_device_id": updated.device_id, "status": updated.status}


# =========================
# ✅ ADMIN: list all devices (admin-only)
# GET /devices/
# =========================
@router.get("/", response_model=List[DeviceOut], dependencies=[Depends(get_current_user)])
def list_devices(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(status_code=403, detail="Chỉ admin mới được xem toàn bộ thiết bị")

    devices = svc.list_devices(db)
    return [DeviceOut.from_orm(d) for d in devices]


# =========================
# ✅ ADMIN: get any device detail (admin-only)
# GET /devices/admin/{device_id}
# =========================
@router.get("/admin/{device_id}", response_model=DeviceOut, dependencies=[Depends(get_current_user)])
def get_device_admin(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(status_code=403, detail="Chỉ admin mới được xem thiết bị người khác")

    d = svc.get_device(db, device_id)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)


# =========================
# ✅ CREATE device
# POST /devices/
# =========================
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
    target_user_id = body.user_id or current_user.user_id

    if body.user_id and body.user_id != current_user.user_id:
        if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Chỉ admin mới được gán thiết bị cho người dùng khác",
            )

    d = svc.create_device(db, body, user_id=target_user_id)
    return DeviceOut.from_orm(d)


# =========================
# ✅ UPDATE device
# PUT /devices/{device_id}
# =========================
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
    # user thường: chỉ update device của mình
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        d0 = svc.get_device(db, device_id)
        if not d0:
            raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
        if getattr(d0, "user_id", None) != current_user.user_id:
            raise HTTPException(status_code=403, detail="Bạn không có quyền sửa thiết bị này")

    d = svc.update_device(db, device_id, body)
    if not d:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return DeviceOut.from_orm(d)


# =========================
# ✅ DELETE device
# DELETE /devices/{device_id}
# =========================
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
    # user thường: chỉ delete device của mình
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        d0 = svc.get_device(db, device_id)
        if not d0:
            raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
        if getattr(d0, "user_id", None) != current_user.user_id:
            raise HTTPException(status_code=403, detail="Bạn không có quyền xoá thiết bị này")

    ok = svc.delete_device(db, device_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
