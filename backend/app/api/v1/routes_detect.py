from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from io import BytesIO
from PIL import Image, UnidentifiedImageError
#from app.services.inference_service import OnnxDetector
from app.services.inference_service import YoloDetector
from sqlalchemy.orm import Session
from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.image_detection import Img, Disease, Detection, SourceType
from app.schemas.detection import DetectionHistoryItem, DetectionDetail
from uuid import uuid4
import os
from pathlib import Path

router = APIRouter(prefix="/detect", tags=["detect"])

# Resolve repo root from this file location to be robust to CWD
THIS_DIR = Path(__file__).resolve().parent  # .../backend/app/api/v1
REPO_ROOT = THIS_DIR.parents[3]             # go up to repo root

# Defaults relative to repo root; allow env overrides
MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml/exports/v1.0/best.pt"))
LABELS_PATH = os.getenv("LABELS_PATH", str(REPO_ROOT / "ml/exports/v1.0/labels.txt"))

try:
    detector = YoloDetector(model_path=MODEL_PATH)
except FileNotFoundError:
    detector = None

@router.post("/analyze")
async def detect(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    if detector is None:
        raise HTTPException(status_code=500, detail=f"Model not available: {MODEL_PATH}")
    try:
        data = await image.read()
                # ===== LƯU FILE ẢNH THẬT RA Ổ ĐĨA (tránh 404) =====
        save_dir = Path("media/detections")
        save_dir.mkdir(parents=True, exist_ok=True)

        ext = Path(image.filename or "").suffix.lower()
        if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
            ext = ".jpg"

        filename = f"{uuid4().hex}{ext}"
        (save_dir / filename).write_bytes(data)

        file_url = f"/media/detections/{filename}"

        try:
            Image.open(BytesIO(data)).verify()
        except UnidentifiedImageError:
            raise HTTPException(status_code=400, detail="Invalid image file")

        result = detector.predict_bytes(data)

        # ===== LƯU LỊCH SỬ VÀO img / detections =====
        img_row = Img(
            source_type=SourceType.camera,
            device_id=None,
            user_id=user.user_id,
            file_url=file_url,
        )
        db.add(img_row)
        db.flush()

        # Lấy disease_name + confidence từ output predict_bytes
        if result["num_detections"] == 0:
            disease_name = "Không phát hiện"
            confidence = 0.0
        else:
            top = result["detections"][0]
            disease_name = top["class_name"]
            try:
                confidence = float(top["confidence"]) * 100.0  # % để lưu DB
            except (TypeError, ValueError):
                confidence = 0.0

        # Tạo / lấy Disease trong DB
        disease_row = db.query(Disease).filter(Disease.name == disease_name).first()
        if not disease_row:
            disease_row = Disease(name=disease_name)
            db.add(disease_row)
            db.flush()


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
            "confidence": confidence / 100.0,  # trả về dạng 0-1
            "detection_id": det.detection_id,
            "img_url": img_row.file_url,
            "created_at": det.created_at.isoformat(),
            "num_detections": result["num_detections"],
            "detections": result["detections"],
            "explanation": result["explanation"],
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
                created_at=det.created_at,
                source_type=img_row.source_type.value if hasattr(img_row.source_type, "value") else str(img_row.source_type),
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
