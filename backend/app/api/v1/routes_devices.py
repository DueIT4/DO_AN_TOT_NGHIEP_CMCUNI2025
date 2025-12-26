from typing import List, Optional, Dict, Any

from fastapi import APIRouter, Depends, HTTPException, status, Query, Response
from sqlalchemy.orm import Session
from pydantic import BaseModel

from app.core.database import get_db
from app.services.device_service import devices_service as svc
from app.api.v1.deps import get_current_user
from app.schemas.devices import DeviceCreate, DeviceUpdate, DeviceOut
from app.models.role import RoleType
from app.models.devices import Device
from app.services.camera_service import capture_image_from_stream
from app.utils.droidcam_helper import DroidCamConfig

router = APIRouter(prefix="/devices", tags=["devices"])


# =========================
# ✅ CREATE device
# POST /devices/
# =========================
@router.post(
    "/admin/devices",
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
# ✅ USER: get selected camera (for home page video stream)
# GET /devices/me/selected
# =========================
@router.get("/me/selected", dependencies=[Depends(get_current_user)])
def get_selected_camera(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get currently selected camera for the user.
    
    Returns:
        {
            "device_id": int,
            "name": str,
            "stream_url": str,
            "status": "active" | "inactive",
            "hls_url": str,  # HLS stream URL
            "message": str
        }
    """
    # Find camera marked as selected (status='active') for this user
    camera = (
        db.query(Device)
        .filter(
            Device.user_id == current_user.user_id,
            Device.device_type_id == 1,  # Assuming device_type_id=1 is camera
            Device.stream_url.isnot(None),
            Device.status == "active",
        )
        .order_by(Device.updated_at.desc())
        .first()
    )
    
    if not camera:
        return {
            "device_id": None,
            "name": None,
            "stream_url": None,
            "status": None,
            "hls_url": None,
            "message": "Không có camera nào được chọn"
        }
    
    hls_url = f"/media/hls/{camera.device_id}/index.m3u8"
    
    return {
        "device_id": camera.device_id,
        "name": camera.name,
        "stream_url": camera.stream_url or camera.gateway_stream_id,
        "status": camera.status,
        "hls_url": hls_url,
        "message": "Thành công"
    }


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



# ✅ UPDATE device (Khớp với FE: /admin/devices/{id})
# =========================
@router.put("/admin/devices/{device_id}")
def update_device_admin(
    device_id: int,
    body: DeviceUpdate,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(status_code=403, detail="Chỉ admin mới có quyền này")

    updated_device = svc.update_device(db, device_id, body)
    if not updated_device:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    
    return updated_device

# =========================
# ✅ DELETE device (Khớp với FE: /admin/devices/{id})
# =========================
@router.delete("/admin/devices/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_device_admin(
    device_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user)
):
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(status_code=403, detail="Chỉ admin mới có quyền này")

    success = svc.delete_device(db, device_id)
    if not success:
        raise HTTPException(status_code=404, detail="Không tìm thấy thiết bị")
    
    return Response(status_code=status.HTTP_204_NO_CONTENT)
# =========================
# ✅ GET stream status for a device
# GET /devices/{device_id}/stream_status
# =========================
@router.get("/{device_id}/stream_status", dependencies=[Depends(get_current_user)])
def get_device_stream_status(
    device_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """Get current stream status for device - useful for UI to show which camera is active.
    
    ✅ FIX: Returns HLS URL, status, and auto-switches stream if needed.
    """
    d = svc.get_device(db, device_id)
    if not d:
        raise HTTPException(status_code=404, detail="Device not found")

    if getattr(d, "user_id", None) != current_user.user_id:
        raise HTTPException(status_code=403, detail="Not allowed to view this device")

    # Import stream service để check status
    from app.services import stream_service
    
    stream_running = stream_service.is_running(device_id)
    stream_info = stream_service.get_stream_info(device_id)
    
    return {
        "device_id": device_id,
        "device_name": d.name,
        "stream_url": d.stream_url,
        "stream_running": stream_running,
        "hls_url": stream_service.hls_url_for(device_id) if stream_running else None,
        "stream_info": stream_info
    }


# =========================
# ✅ TEST RTSP/stream URL connection
# POST /devices/test_stream_url
# =========================
class TestStreamUrlIn(BaseModel):
    stream_url: str
    timeout: Optional[int] = 10


@router.post("/test_stream_url", dependencies=[Depends(get_current_user)])
def test_stream_url(
    payload: TestStreamUrlIn,
    current_user=Depends(get_current_user),
):
    """
    Test RTSP/HTTP stream URL to verify connectivity.
    Useful for validating DroidCam or other camera URLs before saving.
    
    Returns:
        {
            "success": bool,
            "message": str,
            "url_type": "rtsp" | "http" | "https" | "unknown",
            "can_capture": bool,
            "error": Optional[str]
        }
    """
 
    
    url = payload.stream_url.strip()
    
    if not url:
        return {
            "success": False,
            "message": "URL không được để trống",
            "url_type": "unknown",
            "can_capture": False,
            "error": "Empty URL"
        }
    
    # Detect URL type
    url_type = "unknown"
    if url.startswith("rtsp://"):
        url_type = "rtsp"
        # Validate RTSP format
        if not DroidCamConfig.validate_rtsp_url(url):
            return {
                "success": False,
                "message": "URL RTSP không hợp lệ",
                "url_type": url_type,
                "can_capture": False,
                "error": "Invalid RTSP URL format"
            }
    elif url.startswith("https://"):
        url_type = "https"
    elif url.startswith("http://"):
        url_type = "http"
    
    # Try to capture image
    try:
        img_data = capture_image_from_stream(url, timeout=payload.timeout)
        
        if img_data:
            return {
                "success": True,
                "message": f"Kết nối thành công với {url_type.upper()} stream",
                "url_type": url_type,
                "can_capture": True,
                "image_size": len(img_data),
                "tips": "URL hoạt động tốt, bạn có thể lưu vào device"
            }
        else:
            return {
                "success": False,
                "message": f"Không thể lấy ảnh từ {url_type.upper()} stream",
                "url_type": url_type,
                "can_capture": False,
                "error": "Cannot capture frame",
                "tips": "Kiểm tra xem camera đang bật và cùng mạng với server"
            }
    
    except Exception as e:
        return {
            "success": False,
            "message": f"Lỗi khi test stream: {str(e)}",
            "url_type": url_type,
            "can_capture": False,
            "error": str(e),
            "tips": "Kiểm tra URL, network connection và firewall settings"
        }


# =========================
# ✅ GET DroidCam configuration guide
# GET /devices/droidcam_guide
# =========================
@router.get("/droidcam_guide", dependencies=[Depends(get_current_user)])
def get_droidcam_guide(current_user=Depends(get_current_user)):
    """
    Get DroidCam setup guide and URL format examples.
    Helpful for users setting up DroidCam cameras.
    """
    from app.utils.droidcam_helper import DroidCamConfig
    
    tips = DroidCamConfig.get_connection_tips()
    
    # Add example URLs with placeholder IP
    example_ip = "192.168.1.100"
    examples = {
        "rtsp_basic": DroidCamConfig.create_rtsp_url(example_ip),
        "rtsp_with_auth": DroidCamConfig.create_rtsp_url(
            example_ip, 
            username="admin", 
            password="password"
        ),
        "rtsp_udp": DroidCamConfig.create_rtsp_url(example_ip, transport="udp"),
        "http_video": DroidCamConfig.create_http_url(example_ip),
        "http_mjpeg": DroidCamConfig.create_http_url(example_ip, endpoint="mjpegfeed")
    }
    
    return {
        "setup_steps": tips["rtsp_setup"],
        "url_formats": tips["url_formats"],
        "examples": examples,
        "optimal_settings": tips["optimal_settings"],
        "common_issues": tips["common_issues"],
        "note": "Thay <IP> bằng địa chỉ IP thực tế của điện thoại chạy DroidCam"
    }