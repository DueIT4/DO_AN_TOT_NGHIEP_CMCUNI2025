from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.role import RoleType
from app.services.scheduler_service import (
    enable_auto_detect,
    disable_auto_detect,
    is_auto_detect_enabled,
    get_auto_detect_status
)
from app.services import stream_service
from app.models.devices import Device

router = APIRouter(prefix="/auto_detection", tags=["Auto Detection"])


class EnableAutoDetectIn(BaseModel):
    device_id: int


class DisableAutoDetectIn(BaseModel):
    device_id: int


# =========================
# ✅ USER: Enable auto-detection for device
# POST /auto_detection/enable
# =========================
@router.post("/enable", dependencies=[Depends(get_current_user)])
def enable_auto_detection_for_device(
    payload: EnableAutoDetectIn,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Bật auto-detection (mỗi 30s) cho device.
    
    Flow:
    1. Kiểm tra quyền (user phải là chủ device hoặc admin)
    2. Bật auto-detection → scheduler sẽ quét mỗi 30s
    3. Nếu phát hiện bệnh → gửi notification
    4. Nếu cây bình thường → không báo
    """
    device = db.get(Device, payload.device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    # Check permission
    if device.user_id != current_user.user_id:
        if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
            raise HTTPException(status_code=403, detail="Not allowed to enable auto-detection for this device")
    
    # Check if device has stream
    if not device.stream_url and not device.gateway_stream_id:
        raise HTTPException(status_code=400, detail="Device không có stream_url")
    
    # Enable auto-detection
    was_enabled = is_auto_detect_enabled(payload.device_id)
    enable_auto_detect(payload.device_id)
    
    return {
        "device_id": payload.device_id,
        "device_name": device.name,
        "auto_detect_enabled": True,
        "message": "Auto-detection enabled - sẽ quét mỗi 30 giây" if not was_enabled else "Auto-detection already enabled"
    }


# =========================
# ✅ USER: Disable auto-detection for device
# POST /auto_detection/disable
# =========================
@router.post("/disable", dependencies=[Depends(get_current_user)])
def disable_auto_detection_for_device(
    payload: DisableAutoDetectIn,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Tắt auto-detection cho device.
    """
    device = db.get(Device, payload.device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    # Check permission
    if device.user_id != current_user.user_id:
        if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
            raise HTTPException(status_code=403, detail="Not allowed to disable auto-detection for this device")
    
    # Disable auto-detection
    was_enabled = is_auto_detect_enabled(payload.device_id)
    disable_auto_detect(payload.device_id)
    
    return {
        "device_id": payload.device_id,
        "device_name": device.name,
        "auto_detect_enabled": False,
        "message": "Auto-detection disabled" if was_enabled else "Auto-detection already disabled"
    }


# =========================
# ✅ USER: Get auto-detection status for device
# GET /auto_detection/status/{device_id}
# =========================
@router.get("/status/{device_id}", dependencies=[Depends(get_current_user)])
def get_auto_detection_status(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Get auto-detection status for device.
    """
    device = db.get(Device, device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    
    # Check permission
    if device.user_id != current_user.user_id:
        if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
            raise HTTPException(status_code=403, detail="Not allowed to view auto-detection status for this device")
    
    enabled = is_auto_detect_enabled(device_id)
    stream_running = stream_service.is_running(device_id)
    
    return {
        "device_id": device_id,
        "device_name": device.name,
        "auto_detect_enabled": enabled,
        "stream_running": stream_running,
        "message": "Auto-detection is enabled - quét mỗi 30 giây" if enabled else "Auto-detection is disabled"
    }


# =========================
# ✅ ADMIN: Get global auto-detection status
# GET /auto_detection/stats
# =========================
@router.get("/stats", dependencies=[Depends(get_current_user)])
def get_global_auto_detection_stats(
    current_user=Depends(get_current_user),
):
    """
    Get global auto-detection stats (admin only).
    Shows which devices have auto-detection enabled and scheduler status.
    """
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(status_code=403, detail="Chỉ admin mới được xem thống kê")
    
    stats = get_auto_detect_status()
    
    return {
        "scheduler_running": stats["scheduler_running"],
        "active_devices_count": stats["count"],
        "active_devices": stats["active_devices"],
        "message": f"Đang monitor {stats['count']} devices"
    }
