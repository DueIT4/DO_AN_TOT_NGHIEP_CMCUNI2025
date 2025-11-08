from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select
from typing import List, Optional
from app.core.db import get_db
from app.schemas.devices import (
    DeviceCreate, DeviceUpdate, DeviceOut, DeviceListResponse
)
from app.services.device_service import devices_service as svc
from app.models.devices import Devices
from app.models.device_type import DeviceType

router = APIRouter(prefix="/devices", tags=["Devices"])

@router.get("/", response_model=DeviceListResponse)
def list_devices(
    page: int = Query(1, ge=1, description="Số trang"),
    size: int = Query(20, ge=1, le=100, description="Số lượng mỗi trang"),
    user_id: Optional[int] = Query(None, description="Lọc theo user_id"),
    device_type_id: Optional[int] = Query(None, description="Lọc theo device_type_id"),
    status: Optional[str] = Query(None, description="Lọc theo status (active/maintain/inactive)"),
    db: Session = Depends(get_db)
):
    """
    Lấy danh sách thiết bị với pagination và filter.
    """
    # Build query với joinedload để lấy device_type
    query = db.query(Devices).options(joinedload(Devices.device_type))
    
    # Apply filters
    if user_id is not None:
        query = query.filter(Devices.user_id == user_id)
    if device_type_id is not None:
        query = query.filter(Devices.device_type_id == device_type_id)
    if status is not None:
        query = query.filter(Devices.status == status)
    
    # Order by
    query = query.order_by(Devices.created_at.desc())
    
    # Paginate
    result = svc.list(db, page, size, query)
    return DeviceListResponse(**result)

@router.get("/{device_id}", response_model=DeviceOut)
def get_device(
    device_id: int, 
    db: Session = Depends(get_db)
):
    """
    Lấy chi tiết một thiết bị theo ID.
    """
    device = db.query(Devices).options(
        joinedload(Devices.device_type)
    ).filter(Devices.device_id == device_id).first()
    
    if not device:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    
    return DeviceOut.model_validate(device)

@router.post("/", response_model=DeviceOut, status_code=status.HTTP_201_CREATED)
def create_device(
    body: DeviceCreate, 
    db: Session = Depends(get_db)
):
    """
    Tạo mới thiết bị.
    """
    # Validate device_type_id tồn tại
    device_type = db.get(DeviceType, body.device_type_id)
    if not device_type:
        raise HTTPException(status_code=404, detail="Loại thiết bị không tồn tại")
    
    # Convert body to dict
    data = body.model_dump(exclude_unset=True)
    
    try:
        device = svc.create(db, data)
        # Reload với device_type
        db.refresh(device)
        return DeviceOut.model_validate(device)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{device_id}", response_model=DeviceOut)
def update_device(
    device_id: int, 
    body: DeviceUpdate, 
    db: Session = Depends(get_db)
):
    """
    Cập nhật thông tin thiết bị.
    """
    # Validate device_type_id nếu có
    if body.device_type_id is not None:
        device_type = db.get(DeviceType, body.device_type_id)
        if not device_type:
            raise HTTPException(status_code=404, detail="Loại thiết bị không tồn tại")
    
    # Convert body to dict, loại bỏ None values
    data = body.model_dump(exclude_unset=True)
    
    try:
        device = svc.update(db, device_id, data)
        # Reload với device_type
        db.refresh(device)
        return DeviceOut.model_validate(device)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_device(
    device_id: int, 
    db: Session = Depends(get_db)
):
    """
    Xóa thiết bị.
    """
    try:
        svc.delete(db, device_id)
        return None
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
