from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Form
from io import BytesIO
from PIL import Image, UnidentifiedImageError
from app.services.inference_service import OnnxDetector
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.image_detection import Img, Disease, Detection, SourceType
from app.schemas.detection import DetectionHistoryItem, DetectionDetail
import os
from pathlib import Path
from uuid import uuid4
import shutil

router = APIRouter(prefix="/detect", tags=["detect"])

# Resolve repo root from this file location to be robust to CWD
THIS_DIR = Path(__file__).resolve().parent  # .../backend/app/api/v1
REPO_ROOT = THIS_DIR.parents[3]             # go up to repo root

# Defaults relative to repo root; allow env overrides
MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml/exports/v1.0/best.onnx"))
LABELS_PATH = os.getenv("LABELS_PATH", str(REPO_ROOT / "ml/exports/v1.0/labels.txt"))

try:
    detector = OnnxDetector(model_path=MODEL_PATH, labels_path=LABELS_PATH)
except FileNotFoundError:
    detector = None

# Thư mục lưu ảnh detection
IMG_UPLOAD_ROOT = Path("media") / "img"
IMG_UPLOAD_ROOT.mkdir(parents=True, exist_ok=True)

def _save_detection_image(user_id: int, image_data: bytes, filename: str = None) -> str:
    """Lưu ảnh detection vào media/img/{user_id}/{uuid}.jpg"""
    user_dir = IMG_UPLOAD_ROOT / str(user_id)
    user_dir.mkdir(parents=True, exist_ok=True)
    ext = Path(filename).suffix.lower() if filename else ".jpg"
    if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
        ext = ".jpg"
    safe_name = f"{uuid4().hex}{ext}"
    save_path = user_dir / safe_name
    with save_path.open("wb") as f:
        f.write(image_data)
    return f"/media/img/{user_id}/{safe_name}"

@router.post("/analyze")
async def detect(
    image: UploadFile = File(...),
    source_type: str = Form("camera"),  # "camera" hoặc "upload"
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    if detector is None:
        raise HTTPException(status_code=500, detail=f"Model not available: {MODEL_PATH}")
    try:
        data = await image.read()
        img = Image.open(BytesIO(data))
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Invalid image file")
    try:
        result = detector.infer_top1(img)

        # Xác định source_type
        src_type = SourceType.camera if source_type.lower() == "camera" else SourceType.upload
        
        # Lưu file ảnh (data đã được đọc ở trên)
        file_url = _save_detection_image(user.user_id, data, image.filename)

        # ===== LƯU LỊCH SỬ VÀO img / detections =====
        img_row = Img(
            source_type=src_type,
            device_id=None,
            user_id=user.user_id,
            file_url=file_url,
        )
        db.add(img_row)
        db.flush()

        disease_name = str(result.get("disease", "Không xác định"))
        disease_row = db.query(Disease).filter(Disease.name == disease_name).first()
        if not disease_row:
            disease_row = Disease(name=disease_name)
            db.add(disease_row)
            db.flush()

        confidence_raw = result.get("confidence", 0.0) or 0.0
        try:
            confidence = float(confidence_raw) * 100.0
        except (TypeError, ValueError):
            confidence = 0.0

        det = Detection(
            img_id=img_row.img_id,
            disease_id=disease_row.disease_id,
            confidence=confidence,
            description=None,
            treatment_guideline=None,
            model_version=os.path.basename(MODEL_PATH),
        )
        db.add(det)
        db.commit()

        return {
            "disease": disease_name,
            "confidence": result.get("confidence", 0.0),
            "detection_id": det.detection_id,
            "img_url": img_row.file_url,
            "source_type": img_row.source_type.value,
            "created_at": det.created_at.isoformat(),
        }
    except HTTPException:
        raise
    except Exception as e:
        # Surface inference issues clearly to client for debugging
        raise HTTPException(status_code=500, detail=f"Inference error: {e}")


@router.get("/history", response_model=list[DetectionHistoryItem])
def my_history(
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    rows = (
        db.query(Detection, Img, Disease)
        .join(Img, Detection.img_id == Img.img_id)
        .join(Disease, Detection.disease_id == Disease.disease_id, isouter=True)
        .filter(Img.user_id == user.user_id)
        .order_by(Detection.created_at.desc())
        .all()
    )

    items: list[DetectionHistoryItem] = []
    for det, img_row, disease in rows:
        name = disease.name if disease and disease.name else "Không xác định"
        conf = float(det.confidence or 0.0) / 100.0
        items.append(
            DetectionHistoryItem(
                detection_id=det.detection_id,
                disease_name=name,
                confidence=conf,
                img_url=img_row.file_url,
                source_type=img_row.source_type.value,
                created_at=det.created_at,
            )
        )
    return items


@router.get("/history/{detection_id}", response_model=DetectionDetail)
def history_detail(
    detection_id: int,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    det = (
        db.query(Detection, Img, Disease)
        .join(Img, Detection.img_id == Img.img_id)
        .join(Disease, Detection.disease_id == Disease.disease_id, isouter=True)
        .filter(Detection.detection_id == detection_id)
        .first()
    )
    if not det:
        raise HTTPException(status_code=404, detail="Không tìm thấy bản ghi phân tích")

    detection, img_row, disease = det
    if img_row.user_id != user.user_id:
        raise HTTPException(status_code=403, detail="Không có quyền xem bản ghi này")

    name = disease.name if disease and disease.name else "Không xác định"
    conf = float(detection.confidence or 0.0) / 100.0

    return DetectionDetail(
        detection_id=detection.detection_id,
        disease_name=name,
        confidence=conf,
        img_url=img_row.file_url,
        created_at=detection.created_at,
        description=detection.description or disease.description if disease else None,
        treatment_guideline=detection.treatment_guideline
        or (disease.treatment_guideline if disease else None),
    )
