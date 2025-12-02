# app/services/detect_service.py
from pathlib import Path
from datetime import datetime
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from datetime import datetime

from app.models.image_detection import Img, Detection, Disease

MEDIA_ROOT = Path("media") / "detections"
MEDIA_ROOT.mkdir(parents=True, exist_ok=True)

def save_image_to_disk(raw: bytes, original_filename: str) -> str:
    """
    Lưu ảnh vào media/detections/YYYY/MM/DD/...
    Trả về file_url BẮT ĐẦU BẰNG /media/... để FE dùng trực tiếp.
    """

    now = datetime.now()  # dùng giờ local của server
    subdir = MEDIA_ROOT / str(now.year) / f"{now.month:02d}" / f"{now.day:02d}"
    subdir.mkdir(parents=True, exist_ok=True)

    safe_name = original_filename.replace(" ", "_")
    filename = f"{now.strftime('%H%M%S_%f')}_{safe_name}"
    full_path = subdir / filename

    with open(full_path, "wb") as f:
        f.write(raw)

    # ví dụ: rel_path = "detections/2025/11/16/xxx.gif"
    rel_path = full_path.relative_to(Path("media"))
    rel_str = str(rel_path).replace("\\", "/")

    # ✅ Trả về: "/media/detections/2025/11/16/xxx.gif"
    return f"/media/{rel_str}"

def ensure_disease(db: Session, class_name_vi: str) -> Optional[Disease]:
    """
    Tìm hoặc tạo disease theo name (tên bệnh tiếng Việt).
    """
    if not class_name_vi:
        return None
    dis = db.query(Disease).filter(Disease.name == class_name_vi).first()
    if dis:
        return dis
    dis = Disease(name=class_name_vi)
    db.add(dis)
    db.flush()
    return dis


def save_detection_result(
    db: Session,
    raw: bytes,
    filename: str,
    yolo_result: Dict[str, Any],
    user_id: int,
    device_id: int | None = None,
    model_version: str = "v1.0",
) -> Dict[str, Any]:
    """
    LƯU vào DB:
    - ảnh → img
    - mỗi box → detections
    """
    # 1) Lưu ảnh
    file_url = save_image_to_disk(raw, filename)

    img_row = Img(
        source_type="upload" if device_id is None else "camera",
        device_id=device_id,
        user_id=user_id,
        file_url=file_url,
    )
    db.add(img_row)
    db.flush()  # có img_id

    detections_list: List[Dict[str, Any]] = yolo_result.get("detections", [])

    # 2) Lưu từng detection
    for det in detections_list:
        class_name_vi = det.get("class_name")
        confidence = det.get("confidence")
        bbox_list = det.get("bbox", [None, None, None, None])

        bbox_json = {
            "x1": bbox_list[0],
            "y1": bbox_list[1],
            "x2": bbox_list[2],
            "y2": bbox_list[3],
            "image_width": det.get("image_width"),
            "image_height": det.get("image_height"),
        }

        disease_obj = ensure_disease(db, class_name_vi) if class_name_vi else None

        det_row = Detection(
            img_id=img_row.img_id,
            disease_id=disease_obj.disease_id if disease_obj else None,
            confidence=confidence,
            description=None,
            treatment_guideline=None,
            bbox=bbox_json,
            review_status="pending",
            model_version=model_version,
        )
        db.add(det_row)

    db.commit()

    return {
        "img_id": img_row.img_id,
        "file_url": file_url,
    }