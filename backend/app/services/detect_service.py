
from typing import Dict, Any, List, Optional
from datetime import datetime, timezone, timedelta
from sqlalchemy.orm import Session
import logging

from app.models.image_detection import Img, Detection, Disease
from app.models.notification import Notifications
from app.models.devices import Device
from app.services.inference_service import VN_LABELS
from app.services.cloudinary_service import upload_image_to_cloudinary

logger = logging.getLogger(__name__)

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
    image_url: str | None,
    filename: str | None,
    yolo_result: Dict[str, Any],
    user_id: int,
    device_id: int | None = None,
    model_version: str = "v1.0",
    raw: Optional[bytes] = None,  # ✅ Restore: Chấp nhận raw bytes cho auto-detect
    create_alert: bool = True,    # ✅ NEW: Control notification creation (default True)
    source_type: str = "upload"   # ✅ NEW: Explicit source type
) -> Dict[str, Any]:
    """
    LƯU vào DB chuẩn:
    - Mỗi lần dự đoán chỉ tạo DUY NHẤT 1 dòng trong bảng Detection.
    - Lưu toàn bộ danh sách bbox dưới dạng JSON để FE dễ vẽ lại.
    - Hỗ trợ lưu cả trường hợp ảnh không có bệnh.
    """
    # 0) Auto-Upload nếu chưa có URL
    if not image_url and raw:
        try:
            image_url = upload_image_to_cloudinary(raw, folder="zestguard/detections/2025")
            if not image_url:
                logger.warning("[DetectService] ❌ Upload Cloudinary thất bại")
        except Exception as e:
            logger.error(f"[DetectService] ❌ Lỗi upload ảnh: {e}")

    # ⚠️ CRITICAL FIX: Bảng Img yêu cầu file_url NOT NULL.
    # Nếu không có URL (do lỗi upload), ta dùng ảnh placeholder hoặc bỏ qua.
    # ⚠️ CRITICAL FIX: Nếu upload thất bại, DÙNG ẢNH PLACEHOLDER để vẫn lưu được lịch sử
    if not image_url:
        logger.warning("[DetectService] ⚠️ Upload failed. Using placeholder to save detection result.")
        image_url = "https://placehold.co/600x400?text=Check+History+Details"

    # 1) Lưu thông tin ảnh
    final_source_type = "camera" if device_id else source_type 
    img_row = Img(
        source_type=final_source_type,
        device_id=device_id,
        user_id=user_id,
        file_url=image_url,
    )
    db.add(img_row)
    db.flush()

    # 2) Chuẩn bị dữ liệu từ YOLO và LLM
    detections_list = yolo_result.get("detections", [])
    
    # 3) Xử lý logic Confidence thấp (< 0.4) -> Unknown
    # Tìm box có độ tin tưởng cao nhất
    max_conf = 0.0
    primary_disease_id = None
    
    if detections_list:
        best_det = max(detections_list, key=lambda x: x.get("confidence", 0))
        max_conf = best_det.get("confidence", 0)
    
    if max_conf < 0.4:
        guideline_text = "Vui lòng chụp lại ảnh rõ nét, đúng chủ thể (lá/quả) và đủ sáng."
        description_text = "Không phát hiện bệnh cây trồng trên ảnh, vui lòng chụp lại."
        
        # Disease ID = None (hoặc 1 loại disease 'Unknown' nếu muốn)
        # Ở đây ta để None, FE sẽ hiển thị diseaseName dựa vào logic fallback hoặc ta tạo disease "Không xác định"
        # Tốt nhất: Tìm/Tạo disease tên "Không xác định" để FE hiện title
        unknown_disease = ensure_disease(db, "Không xác định")
        primary_disease_id = unknown_disease.disease_id if unknown_disease else None
        
        # Xóa detections list để không vẽ box linh tinh
        detections_list = []
        
    else:
        # Logic bình thường (> 0.4)
        llm = yolo_result.get("llm") or {}
        description_text = llm.get("disease_summary") or yolo_result.get("explanation")
        guideline_text = llm.get("care_instructions")
        
        if detections_list:
            best_det = max(detections_list, key=lambda x: x.get("confidence", 0))
            # ✅ FIX: Map sang tiếng Việt
            raw_class_name = best_det.get("class_name")
            class_name_vi = VN_LABELS.get(raw_class_name, raw_class_name)
            
            disease_obj = ensure_disease(db, class_name_vi) if class_name_vi else None
            if disease_obj:
                primary_disease_id = disease_obj.disease_id

    # 4) Lưu DUY NHẤT một dòng vào bảng Detection
    # Dữ liệu từ inference_service đã được map sang tiếng Việt (hoặc giữ nguyên tên gốc)
    # nên ta lưu thẳng vào DB.

    det_row = Detection(
        img_id=img_row.img_id,
        disease_id=primary_disease_id,
        confidence=max_conf,
        description=description_text,
        treatment_guideline=guideline_text,
        # Lưu toàn bộ list detections vào cột bbox
        bbox={"all_detections": detections_list}, 
        review_status="pending",
        model_version=model_version,
        # ✅ FIX DATE: Dùng UTC để endpoint mobile hiển thị đúng giờ local
        created_at=datetime.now(timezone.utc) 
    )
    db.add(det_row)
    
    # 5) Tự động tạo thông báo (Notification) nếu là Camera + Có bệnh + Không spam (30p/lần)
    if create_alert and device_id and primary_disease_id:
        try:
            # Lấy thông tin Disease
            disease_record = db.query(Disease).filter(Disease.disease_id == primary_disease_id).first()
            if disease_record:
                d_name = disease_record.name.lower()
                dev_name = "Camera"
                # Lấy tên Device
                device_obj = db.query(Device).filter(Device.device_id == device_id).first()
                if device_obj:
                     dev_name = device_obj.name

                # Rate Limit Check (chung cho mọi loại thông báo để tránh spam)
                cutoff = datetime.now(timezone.utc) - timedelta(minutes=30)
                recent_noti = db.query(Notifications).filter(
                    Notifications.user_id == user_id,
                    Notifications.created_at >= cutoff,
                    Notifications.description.like(f"%{disease_record.name}%")
                ).first()

                if not recent_noti:
                    # CASE 1: Bệnh Khỏe -> KHÔNG GỬI
                    if "healthy" in d_name or "khỏe" in d_name:
                        logger.info(f"[DetectService] Skip notification for healthy: {disease_record.name}")
                    
                    # CASE 2: Không xác định -> Gửi thông báo ảnh không hỗ trợ
                    elif "không xác định" in d_name or "unknown" in d_name:
                        new_noti = Notifications(
                            user_id=user_id,
                            title="⚠️ Thông báo ảnh tự động",
                            description=f"Hình ảnh thu được từ {dev_name} hệ thống không hỗ trợ phát hiện bệnh. Vui lòng check lịch sử tại trang phân tích.",
                            created_at=datetime.now(timezone(timedelta(hours=7)))
                        )
                        db.add(new_noti)
                        db.commit()
                        logger.info(f"[DetectService] Created 'Unknown' notification for user {user_id}")

                    # CASE 3: Có bệnh -> Gửi thông báo hiện trạng
                    else:
                        dev_loc = device_obj.location if (device_obj and device_obj.location) else "Chưa định vị"
                        new_noti = Notifications(
                            user_id=user_id,
                            title=f"⚠️ Phát hiện bệnh : {disease_record.name}",
                            description=f"vị trí camera : {dev_loc}. Vui lòng kiểm tra lịch sử tại trang phân tích.",
                            created_at=datetime.now(timezone(timedelta(hours=7)))
                        )
                        db.add(new_noti)
                        db.commit()
                        logger.info(f"[DetectService] Created 'Disease' notification for user {user_id}: {disease_record.name}")

        except Exception as e:
            # Không để lỗi notify làm hỏng luồng chính
            logger.error(f"[DetectService] Error creating notification: {e}", exc_info=True)
            # Quan trọng: Rollback phần notification nếu lỗi để session sạch sẽ
            db.rollback()
            raise e

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
