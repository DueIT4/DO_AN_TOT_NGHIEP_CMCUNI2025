from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.devices import Device
from app.models.image_detection import Detection, Img, Disease
from app.schemas.devices import DeviceOut
from app.schemas.detection import DetectionHistoryItem

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
