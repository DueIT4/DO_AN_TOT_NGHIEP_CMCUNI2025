from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.devices import Device
from app.models.device_type import DeviceType
from app.models.image_detection import Detection, Img, Disease
from app.schemas.devices import DeviceOut
from app.schemas.detection import DetectionHistoryItem
from pydantic import BaseModel

router = APIRouter(prefix="/devices", tags=["devices"])


@router.get("/", response_model=list[DeviceOut])
def list_my_devices(db: Session = Depends(get_db), user = Depends(get_current_user)):
    devices = db.query(Device).filter(Device.user_id == user.user_id).all()
    return devices


@router.get("/{device_id}/latest_detection")
def device_latest_detection(device_id: int, db: Session = Depends(get_db), user = Depends(get_current_user)):
    device = db.get(Device, device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if device.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Not allowed to view this device")

    row = (
        db.query(Detection, Img, Disease)
        .join(Img, Detection.img_id == Img.img_id)
        .join(Disease, Detection.disease_id == Disease.disease_id, isouter=True)
        .filter(Img.device_id == device_id)
        .order_by(Detection.created_at.desc())
        .first()
    )

    if not row:
        return {"found": False}

    det, img_row, disease = row
    name = disease.name if disease and disease.name else "Không xác định"
    conf = float(det.confidence or 0.0) / 100.0

    return {
        "found": True,
        "detection_id": det.detection_id,
        "disease_name": name,
        "confidence": conf,
        "img_url": img_row.file_url,
        "created_at": det.created_at,
    }


class SelectCameraIn(BaseModel):
    device_id: int


@router.post("/select_camera")
def select_camera(payload: SelectCameraIn, db: Session = Depends(get_db), user = Depends(get_current_user)):
    device = db.get(Device, payload.device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    if device.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Not allowed")

    # chỉ áp dụng cho thiết bị có stream (camera)
    dt = db.get(DeviceType, device.device_type_id)
    if not dt or not dt.has_stream:
        raise HTTPException(status_code=400, detail="Device is not a camera")

    # inactive tất cả camera của user (tránh dùng join() trong update gây InvalidRequestError)
    db.query(Device).filter(
        Device.user_id == user.user_id,
        Device.device_type.has(DeviceType.has_stream == True)
    ).update({Device.status: "inactive"}, synchronize_session=False)

    # set active cho camera được chọn
    device.status = "active"
    db.commit()
    db.refresh(device)

    return {"selected_device_id": device.device_id, "status": device.status}
