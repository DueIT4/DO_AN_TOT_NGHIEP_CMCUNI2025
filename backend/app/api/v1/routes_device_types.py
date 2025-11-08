from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from app.core.db import get_db
from app.schemas.device_type import DeviceTypeOut, DeviceTypeCreate, DeviceTypeUpdate
from app.models.device_type import DeviceType, DeviceStatus

router = APIRouter(prefix="/device-types", tags=["Device Types"])

@router.get("/", response_model=List[DeviceTypeOut])
def list_device_types(
    status: str = None,
    db: Session = Depends(get_db)
):
    """
    Lấy danh sách tất cả loại thiết bị.
    """
    query = db.query(DeviceType)
    
    # Filter theo status nếu có
    if status:
        try:
            status_enum = DeviceStatus(status)
            query = query.filter(DeviceType.status == status_enum)
        except ValueError:
            raise HTTPException(
                status_code=400, 
                detail=f"Status không hợp lệ. Chỉ chấp nhận: {[s.value for s in DeviceStatus]}"
            )
    
    return query.order_by(DeviceType.device_type_name).all()

@router.get("/{device_type_id}", response_model=DeviceTypeOut)
def get_device_type(
    device_type_id: int,
    db: Session = Depends(get_db)
):
    """
    Lấy chi tiết một loại thiết bị theo ID.
    """
    device_type = db.get(DeviceType, device_type_id)
    if not device_type:
        raise HTTPException(status_code=404, detail="Không tìm thấy loại thiết bị")
    return device_type

@router.post("/", response_model=DeviceTypeOut, status_code=status.HTTP_201_CREATED)
def create_device_type(
    body: DeviceTypeCreate,
    db: Session = Depends(get_db)
):
    """
    Tạo mới loại thiết bị.
    """
    # Kiểm tra trùng tên
    existing = db.query(DeviceType).filter(
        DeviceType.device_type_name == body.device_type_name
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Tên loại thiết bị đã tồn tại")
    
    device_type = DeviceType(
        device_type_name=body.device_type_name,
        has_stream=body.has_stream,
        status=body.status
    )
    db.add(device_type)
    db.commit()
    db.refresh(device_type)
    return device_type

@router.put("/{device_type_id}", response_model=DeviceTypeOut)
def update_device_type(
    device_type_id: int,
    body: DeviceTypeUpdate,
    db: Session = Depends(get_db)
):
    """
    Cập nhật loại thiết bị.
    """
    device_type = db.get(DeviceType, device_type_id)
    if not device_type:
        raise HTTPException(status_code=404, detail="Không tìm thấy loại thiết bị")
    
    # Kiểm tra trùng tên nếu đổi tên
    if body.device_type_name and body.device_type_name != device_type.device_type_name:
        existing = db.query(DeviceType).filter(
            DeviceType.device_type_name == body.device_type_name,
            DeviceType.device_type_id != device_type_id
        ).first()
        if existing:
            raise HTTPException(status_code=400, detail="Tên loại thiết bị đã tồn tại")
    
    # Update các trường
    if body.device_type_name is not None:
        device_type.device_type_name = body.device_type_name
    if body.has_stream is not None:
        device_type.has_stream = body.has_stream
    if body.status is not None:
        device_type.status = body.status
    
    db.commit()
    db.refresh(device_type)
    return device_type

@router.delete("/{device_type_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_device_type(
    device_type_id: int,
    db: Session = Depends(get_db)
):
    """
    Xóa loại thiết bị.
    Lưu ý: Chỉ xóa được nếu không có thiết bị nào đang sử dụng loại này.
    """
    device_type = db.get(DeviceType, device_type_id)
    if not device_type:
        raise HTTPException(status_code=404, detail="Không tìm thấy loại thiết bị")
    
    # Kiểm tra có thiết bị nào đang dùng không
    from app.models.devices import Devices
    devices_count = db.query(Devices).filter(
        Devices.device_type_id == device_type_id
    ).count()
    
    if devices_count > 0:
        raise HTTPException(
            status_code=400, 
            detail=f"Không thể xóa loại thiết bị này vì có {devices_count} thiết bị đang sử dụng"
        )
    
    db.delete(device_type)
    db.commit()
    return None

