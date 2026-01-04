# app/services/detect_service.py

from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from app.models.image_detection import Img, Detection, Disease


# ======================================================
# Helpers
# ======================================================

def ensure_disease(db: Session, class_name_vi: str) -> Optional[Disease]:
    """
    Tìm hoặc tạo disease theo tên tiếng Việt
    """
    if not class_name_vi:
        return None

    disease = db.query(Disease).filter(Disease.name == class_name_vi).first()
    if disease:
        return disease

    disease = Disease(name=class_name_vi)
    db.add(disease)
    db.flush()
    return disease


def normalize_bbox(det: Dict[str, Any]) -> Dict[str, Any]:
    """
    Chuẩn hóa bbox để FE luôn vẽ được
    """
    bbox = det.get("bbox")

    if isinstance(bbox, dict):
        return {
            "x1": bbox.get("x1"),
            "y1": bbox.get("y1"),
            "x2": bbox.get("x2"),
            "y2": bbox.get("y2"),
            "image_width": bbox.get("image_width", det.get("image_width")),
            "image_height": bbox.get("image_height", det.get("image_height")),
        }

    if isinstance(bbox, (list, tuple)) and len(bbox) >= 4:
        return {
            "x1": bbox[0],
            "y1": bbox[1],
            "x2": bbox[2],
            "y2": bbox[3],
            "image_width": det.get("image_width"),
            "image_height": det.get("image_height"),
        }

    return {
        "x1": None,
        "y1": None,
        "x2": None,
        "y2": None,
        "image_width": det.get("image_width"),
        "image_height": det.get("image_height"),
    }


# ======================================================
# MAIN SERVICE – hỗ trợ upload + stream
# ======================================================

from app.services.cloudinary_service import upload_image_to_cloudinary

def save_detection_result(
    db: Session,
    *,
    image_url: Optional[str] = None,
    filename: Optional[str] = None,
    yolo_result: Dict[str, Any],
    user_id: int,
    device_id: Optional[int] = None,
    is_stream: bool = False,
    model_version: str = "v1.0",
    raw: Optional[bytes] = None,  # ✅ ADDED: Chấp nhận raw bytes
) -> Dict[str, Any]:
    """
    LƯU KẾT QUẢ DỰ ĐOÁN (CHUẨN CLOUD + STREAM)

    - Upload ảnh → image_url (Cloudinary / GCS)
    - Stream camera → image_url có thể None (nếu ko có raw) hoặc upload raw lên Cloudinary
    """

    # ==================================================
    # 0. Upload nếu cần (quan trọng cho auto-detect)
    # ==================================================
    if not image_url and raw:
        try:
            # Upload lên folder stream để phân loại
            image_url = upload_image_to_cloudinary(raw, folder="zestguard/stream_detect")
        except Exception:
            # Nếu upload lỗi, vẫn tiếp tục lưu DB nhưng file_url=None (hoặc có thể raise)
            pass

    # ==================================================
    # 1. Tạo bản ghi IMG
    # ==================================================
    img_row = Img(
        source_type="stream" if is_stream else ("upload" if device_id is None else "camera"),
        device_id=device_id,
        user_id=user_id,
        file_url=image_url,     # Đã có URL nếu upload thành công
        original_name=filename, # optional
    )
    db.add(img_row)
    db.flush()  # có img_id

    # ==================================================
    # 2. Chuẩn bị dữ liệu YOLO + LLM
    # ==================================================
    detections: List[Dict[str, Any]] = yolo_result.get("detections", [])

    llm = yolo_result.get("llm") or {}
    description = llm.get("disease_summary") or yolo_result.get("explanation")
    guideline = llm.get("care_instructions")

    # ==================================================
    # 3. Xác định bệnh chính (confidence cao nhất)
    # ==================================================
    primary_disease_id = None
    max_confidence = None

    if detections:
        best_det = max(detections, key=lambda d: d.get("confidence", 0))
        max_confidence = best_det.get("confidence")
        class_name = best_det.get("class_name")

        disease = ensure_disease(db, class_name)
        if disease:
            primary_disease_id = disease.disease_id

    # ==================================================
    # 4. Chuẩn hóa toàn bộ bbox (FE dùng trực tiếp)
    # ==================================================
    normalized_detections = []
    for det in detections:
        normalized_detections.append({
            "class_name": det.get("class_name"),
            "confidence": det.get("confidence"),
            "bbox": normalize_bbox(det),
        })

    # ==================================================
    # 5. Lưu DUY NHẤT 1 dòng Detection
    # ==================================================
    det_row = Detection(
        img_id=img_row.img_id,
        disease_id=primary_disease_id,
        confidence=max_confidence,
        description=description,
        treatment_guideline=guideline,
        bbox={
            "all_detections": normalized_detections,
            "is_stream": is_stream,
        },
        review_status="pending",
        model_version=model_version,
    )

    db.add(det_row)

    try:
        db.commit()
    except Exception:
        db.rollback()
        raise

    # ==================================================
    # 6. Response
    # ==================================================
    return {
        "img_id": img_row.img_id,
        "detection_id": det_row.detection_id,
        "file_url": image_url,
        "is_stream": is_stream,
        "detections_count": len(normalized_detections),
    }
