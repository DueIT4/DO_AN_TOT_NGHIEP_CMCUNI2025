from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.role import RoleType
from app.schemas.device_type import (
    DeviceTypeCreate,
    DeviceTypeUpdate,
    DeviceTypeOut,
)
from app.services.device_type_service import device_type_service as svc

router = APIRouter( tags=["Device Type"])


# =============================
# 1) GET danh sách loại thiết bị (public / ai cũng dùng được)
# =============================
@router.get("/device-types", response_model=List[DeviceTypeOut])
def list_device_types(db: Session = Depends(get_db)):
    dts = svc.list_device_types(db)
    return [DeviceTypeOut.model_validate(dt) for dt in dts]


# =============================
# 2) GET chi tiết 1 loại thiết bị (public)
# =============================
@router.get("/{device_type_id}", response_model=DeviceTypeOut)
def get_device_type(device_type_id: int, db: Session = Depends(get_db)):
    dt = svc.get_device_type(db, device_type_id)
    if not dt:
        raise HTTPException(status_code=404, detail="Không tìm thấy loại thiết bị")
    return DeviceTypeOut.model_validate(dt)


# =============================
# 3) CREATE loại thiết bị (CHỈ ADMIN / SUPPORT_ADMIN)
# =============================
@router.post(
    "/",
    response_model=DeviceTypeOut,
    status_code=status.HTTP_201_CREATED,
)
def create_device_type(
    body: DeviceTypeCreate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được tạo loại thiết bị",
        )

    dt = svc.create_device_type(db, body)
    return DeviceTypeOut.model_validate(dt)


# =============================
# 4) UPDATE loại thiết bị (CHỈ ADMIN / SUPPORT_ADMIN)
# =============================
@router.put(
    "/{device_type_id}",
    response_model=DeviceTypeOut,
)
def update_device_type(
    device_type_id: int,
    body: DeviceTypeUpdate,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được sửa loại thiết bị",
        )

    dt = svc.update_device_type(db, device_type_id, body)
    if not dt:
        raise HTTPException(status_code=404, detail="Không tìm thấy loại thiết bị")
    return DeviceTypeOut.model_validate(dt)


# =============================
# 5) DELETE loại thiết bị (CHỈ ADMIN / SUPPORT_ADMIN)
# =============================
@router.delete(
    "/{device_type_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_device_type(
    device_type_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được xoá loại thiết bị",
        )

    try:
        ok = svc.delete_device_type(db, device_type_id)
    except Exception:
        # thường do ràng buộc FK: còn devices đang dùng device_type này
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Không thể xoá loại thiết bị vì đang được dùng bởi thiết bị khác",
        )

    if not ok:
        raise HTTPException(status_code=404, detail="Không tìm thấy loại thiết bị")

    return
