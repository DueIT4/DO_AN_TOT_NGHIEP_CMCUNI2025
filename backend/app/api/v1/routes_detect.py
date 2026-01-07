
from typing import Optional
import logging
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.inference_service import detector
from app.services.llm_service import summarize_detections_with_llm
from app.services.detect_service import save_detection_result
from app.api.v1.deps import get_optional_user
from app.services.detect_limit_service import check_guest_detect_limit

logger = logging.getLogger(__name__)
router = APIRouter(tags=["Detection"])

@router.post("/detect")
async def detect_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_optional_user),
    client_key: Optional[str] = Header(default=None, alias="X-Client-Key"),
):
    """
    ✅ FIXED: Luôn lưu lịch sử cho user đã đăng nhập, kể cả ảnh không phát hiện bệnh
    ✅ FIXED: Trả về lỗi rõ ràng thay vì 500 chung chung
    """
    # 1. Kiểm tra model
    if detector is None:
        logger.error("[Detect API] Model not loaded on server")
        raise HTTPException(
            status_code=503,
            detail="Model chưa được tải. Vui lòng thử lại sau hoặc liên hệ quản trị viên."
        )

    # 2. Đọc dữ liệu file
    try:
        raw = await file.read()
        if not raw or len(raw) == 0:
            raise HTTPException(status_code=400, detail="File rỗng hoặc không hợp lệ")
    except Exception as e:
        logger.error(f"[Detect API] Cannot read file: {e}")
        raise HTTPException(status_code=400, detail=f"Không đọc được file: {str(e)}")

    # 3. Kiểm tra hạn mức cho khách vãng lai
    if current_user is None:
        if not client_key:
            raise HTTPException(
                status_code=400,
                detail="Thiếu header X-Client-Key cho khách không đăng nhập.",
            )
        try:
            check_guest_detect_limit(db, client_key)
        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"[Detect API] Guest limit check failed: {e}")
            raise HTTPException(status_code=500, detail="Lỗi kiểm tra hạn mức")

    # 4. Chạy nhận diện YOLO
    try:
        yolo_result = detector.predict_bytes(raw_bytes=raw, conf=0.5, iou=0.5)
    except Exception as e:
        logger.error(f"[Detect API] YOLO prediction failed: {e}", exc_info=True)
        raise HTTPException(status_code=400, detail=f"Không thể xử lý ảnh: {str(e)}")

    detections_list = yolo_result.get("detections", [])
    num_detections = yolo_result.get("num_detections", 0)
    explanation = yolo_result.get("explanation")

    # 5. Gọi LLM để tóm tắt (Chỉ gọi nếu confidence >= 0.4)
    max_conf = 0.0
    best_disease = "Không xác định"
    
    if detections_list:
        detections_list.sort(key=lambda x: x.get("confidence", 0), reverse=True)
        top = detections_list[0]
        max_conf = top.get("confidence", 0)
        best_disease = top.get("class_name", "Không xác định")

    if max_conf < 0.4:
        disease_summary = "Không phát hiện bệnh cây trồng trên ảnh, vui lòng chụp lại."
        care_instructions = "Vui lòng chụp lại ảnh rõ nét, đúng chủ thể (lá/quả) và đủ sáng."
    else:
        try:
            disease_summary, care_instructions = summarize_detections_with_llm(detections_list)
        except Exception as e:
            logger.warning(f"[Detect API] LLM summary failed: {e}")
            disease_summary = "Phát hiện bệnh nhưng chưa có phân tích chi tiết."
            care_instructions = "Vui lòng kiểm tra lại sau."

    yolo_result["llm"] = {
        "disease_summary": disease_summary,
        "care_instructions": care_instructions,
    }
    if "explanation" not in yolo_result:
        yolo_result["explanation"] = explanation

    # 6. Chuẩn bị response (chưa có URL vì chưa lưu)
    response_data = {
        "file_name": file.filename,
        "saved_to_db": False,
        "url": None,
        "file_url": None,
        "img": {
            "img_id": None,
            "file_url": None,
            "source_type": "upload"
        },
        "num_detections": num_detections,
        "detections": detections_list,
        "explanation": explanation,
        "llm": yolo_result["llm"],
        "disease_name": best_disease,
        "confidence": max_conf
    }

    # 7. Phản hồi cho Guest (Không lưu DB)
    if current_user is None:
        logger.info(f"[Detect API] Guest detection: {best_disease} ({max_conf:.2f})")
        return JSONResponse(response_data)

    # 8. User đã đăng nhập: LƯU VÀO DB (kể cả không phát hiện bệnh)
    try:
        saved = save_detection_result(
            db=db,
            image_url=None,  # Để service tự upload
            raw=raw,  # Truyền raw bytes để service upload
            filename=file.filename,
            yolo_result=yolo_result,
            user_id=current_user.user_id,
            device_id=None,
            model_version="v1.0",
            create_alert=False  # Upload từ web không cần thông báo
        )

        # ✅ Cập nhật response với thông tin đã lưu
        response_data["saved_to_db"] = True
        response_data["url"] = saved.get("file_url")
        response_data["file_url"] = saved.get("file_url")
        response_data["img"]["img_id"] = saved.get("img_id")
        response_data["img"]["file_url"] = saved.get("file_url")
        # ✅ Truyền detection_id về FE để highlight
        response_data["detection_id"] = saved.get("detection_id")
        response_data["id"] = saved.get("detection_id") # Hỗ trợ cả 2 key cho chắc/tương thích model cũ

        logger.info(f"[DetectService] Saved for user {current_user.user_id}: {best_disease} ({max_conf:.2f})")
        
    except Exception as e:
        # ✅ CRITICAL: Không để lỗi lưu DB làm crash API
        # Vẫn trả kết quả nhưng báo không lưu được
        logger.error(f"[Detect API] Failed to save to DB: {e}", exc_info=True)
        response_data["saved_to_db"] = False
        response_data["error"] = "Phát hiện thành công nhưng không lưu được lịch sử"

    return JSONResponse(response_data)