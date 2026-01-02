# # app/services/detect_service.py
# from pathlib import Path
# from datetime import datetime
# from typing import Dict, Any, List, Optional
# from sqlalchemy.orm import Session

# from app.models.image_detection import Img, Detection, Disease

# MEDIA_ROOT = Path("media") / "detections"
# MEDIA_ROOT.mkdir(parents=True, exist_ok=True)


# def save_image_to_disk(raw: bytes, original_filename: str) -> str:
#     """
#     Lưu ảnh vào media/detections/YYYY/MM/DD/...
#     Trả về file_url BẮT ĐẦU BẰNG /media/... để FE dùng trực tiếp.
#     """
#     now = datetime.now()  # dùng giờ local của server
#     subdir = MEDIA_ROOT / str(now.year) / f"{now.month:02d}" / f"{now.day:02d}"
#     subdir.mkdir(parents=True, exist_ok=True)

#     safe_name = original_filename.replace(" ", "_")
#     filename = f"{now.strftime('%H%M%S_%f')}_{safe_name}"
#     full_path = subdir / filename

#     with open(full_path, "wb") as f:
#         f.write(raw)

#     rel_path = full_path.relative_to(Path("media"))
#     rel_str = str(rel_path).replace("\\", "/")
#     return f"/media/{rel_str}"


# def ensure_disease(db: Session, class_name_vi: str) -> Optional[Disease]:
#     """
#     Tìm hoặc tạo disease theo name (tên bệnh tiếng Việt).
#     """
#     if not class_name_vi:
#         return None
#     dis = db.query(Disease).filter(Disease.name == class_name_vi).first()
#     if dis:
#         return dis
#     dis = Disease(name=class_name_vi)
#     db.add(dis)
#     db.flush()
#     return dis


# def _normalize_bbox(det: Dict[str, Any]) -> Dict[str, Any]:
#     """
#     Hỗ trợ 2 kiểu bbox:
#     - list/tuple: [x1, y1, x2, y2]
#     - dict: {"x1":..., "y1":..., "x2":..., "y2":..., "image_width":..., "image_height":...}
#     """
#     bbox = det.get("bbox")

#     # Case 1: bbox là dict (đúng kiểu bạn gửi)
#     if isinstance(bbox, dict):
#         return {
#             "x1": bbox.get("x1"),
#             "y1": bbox.get("y1"),
#             "x2": bbox.get("x2"),
#             "y2": bbox.get("y2"),
#             "image_width": bbox.get("image_width", det.get("image_width")),
#             "image_height": bbox.get("image_height", det.get("image_height")),
#         }

#     # Case 2: bbox là list/tuple [x1,y1,x2,y2]
#     if isinstance(bbox, (list, tuple)) and len(bbox) >= 4:
#         return {
#             "x1": bbox[0],
#             "y1": bbox[1],
#             "x2": bbox[2],
#             "y2": bbox[3],
#             "image_width": det.get("image_width"),
#             "image_height": det.get("image_height"),
#         }

#     # Fallback: không có bbox/không đúng định dạng
#     return {
#         "x1": None,
#         "y1": None,
#         "x2": None,
#         "y2": None,
#         "image_width": det.get("image_width"),
#         "image_height": det.get("image_height"),
#     }


# def save_detection_result(
#     db: Session,
#     raw: bytes,
#     filename: str,
#     yolo_result: Dict[str, Any],
#     user_id: int,
#     device_id: int | None = None,
#     model_version: str = "v1.0",
# ) -> Dict[str, Any]:
#     """
#     LƯU vào DB:
#     - ảnh → img
#     - mỗi box → detections
#     - ✅ Lưu thêm: description + treatment_guideline
#     """
#     # 1) Lưu ảnh (GIỮ NGUYÊN LOGIC GỐC CỦA BẠN)
#     file_url = save_image_to_disk(raw, filename)

#     img_row = Img(
#         source_type="upload" if device_id is None else "camera",
#         device_id=device_id,
#         user_id=user_id,
#         file_url=file_url,
#     )
#     db.add(img_row)
#     db.flush()  # có img_id

#     detections_list: List[Dict[str, Any]] = yolo_result.get("detections", [])

#     # ✅ NEW: lấy text để lưu vào 2 cột bạn cần (ưu tiên LLM)
#     llm = yolo_result.get("llm") or {}
#     description_text = llm.get("disease_summary") or yolo_result.get("explanation")
#     guideline_text = llm.get("care_instructions")

#     # 2) Lưu từng detection
#     for det in detections_list:
#         class_name_vi = det.get("class_name")
#         confidence = det.get("confidence")

#         bbox_json = _normalize_bbox(det)

#         disease_obj = ensure_disease(db, class_name_vi) if class_name_vi else None

#         det_row = Detection(
#             img_id=img_row.img_id,
#             disease_id=disease_obj.disease_id if disease_obj else None,
#             confidence=confidence,

#             # ✅ NEW: lưu thẳng vào DB
#             description=description_text,
#             treatment_guideline=guideline_text,

#             bbox=bbox_json,
#             review_status="pending",
#             model_version=model_version,
#         )
#         db.add(det_row)

#     db.commit()

#     return {
#         "img_id": img_row.img_id,
#         "file_url": file_url,
#     }
from typing import Dict, Any, List, Optional
from sqlalchemy.orm import Session
from app.models.image_detection import Img, Detection, Disease

# Không còn dùng MEDIA_ROOT và save_image_to_disk để đảm bảo chạy được trên Cloud Run

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


def _normalize_bbox(det: Dict[str, Any]) -> Dict[str, Any]:
    """
    Hỗ trợ 2 kiểu bbox:
    - list/tuple: [x1, y1, x2, y2]
    - dict: {"x1":..., "y1":..., "x2":..., "y2":..., "image_width":..., "image_height":...}
    """
    bbox = det.get("bbox")

    # Case 1: bbox là dict
    if isinstance(bbox, dict):
        return {
            "x1": bbox.get("x1"),
            "y1": bbox.get("y1"),
            "x2": bbox.get("x2"),
            "y2": bbox.get("y2"),
            "image_width": bbox.get("image_width", det.get("image_width")),
            "image_height": bbox.get("image_height", det.get("image_height")),
        }

    # Case 2: bbox là list/tuple [x1,y1,x2,y2]
    if isinstance(bbox, (list, tuple)) and len(bbox) >= 4:
        return {
            "x1": bbox[0],
            "y1": bbox[1],
            "x2": bbox[2],
            "y2": bbox[3],
            "image_width": det.get("image_width"),
            "image_height": det.get("image_height"),
        }

    # Fallback
    return {
        "x1": None,
        "y1": None,
        "x2": None,
        "y2": None,
        "image_width": det.get("image_width"),
        "image_height": det.get("image_height"),
    }
def save_detection_result(
    db: Session,
    image_url: str,
    filename: str,
    yolo_result: Dict[str, Any],
    user_id: int,
    device_id: int | None = None,
    model_version: str = "v1.0",
) -> Dict[str, Any]:
    """
    LƯU vào DB chuẩn:
    - Mỗi lần dự đoán chỉ tạo DUY NHẤT 1 dòng trong bảng Detection.
    - Lưu toàn bộ danh sách bbox dưới dạng JSON để FE dễ vẽ lại.
    - Hỗ trợ lưu cả trường hợp ảnh không có bệnh.
    """
    # 1) Lưu thông tin ảnh (luôn duy nhất 1 dòng)
    img_row = Img(
        source_type="upload" if device_id is None else "camera",
        device_id=device_id,
        user_id=user_id,
        file_url=image_url,  # URL Cloudinary
    )
    db.add(img_row)
    db.flush()

    # 2) Chuẩn bị dữ liệu từ YOLO và LLM
    detections_list = yolo_result.get("detections", [])
    llm = yolo_result.get("llm") or {}
    description_text = llm.get("disease_summary") or yolo_result.get("explanation")
    guideline_text = llm.get("care_instructions")

    # 3) Xác định bệnh "chính" để lưu vào disease_id (Bệnh có confidence cao nhất)
    primary_disease_id = None
    max_conf = 0.0
    
    if detections_list:
        # Tìm box có độ tin tưởng cao nhất
        best_det = max(detections_list, key=lambda x: x.get("confidence", 0))
        max_conf = best_det.get("confidence", 0)
        class_name_vi = best_det.get("class_name")
        
        disease_obj = ensure_disease(db, class_name_vi) if class_name_vi else None
        if disease_obj:
            primary_disease_id = disease_obj.disease_id

    # 4) Lưu DUY NHẤT một dòng vào bảng Detection
    # Gộp toàn bộ bbox vào một cột để tránh lặp dữ liệu
    det_row = Detection(
        img_id=img_row.img_id,
        disease_id=primary_disease_id,
        confidence=max_conf,
        description=description_text,
        treatment_guideline=guideline_text,
        # Lưu toàn bộ list detections vào cột bbox (giả định cột này lưu JSON)
        bbox={"all_detections": detections_list}, 
        review_status="pending",
        model_version=model_version,
    )
    db.add(det_row)
    
    try:
        db.commit()
    except Exception as e:
        db.rollback()
        raise e

    return {
        "img_id": img_row.img_id,
        "file_url": image_url,
        "detection_id": det_row.detection_id
    }