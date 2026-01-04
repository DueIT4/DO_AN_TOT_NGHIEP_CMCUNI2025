
from typing import Optional
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.inference_service import detector
from app.services.llm_service import summarize_detections_with_llm
from app.services.detect_service import save_detection_result
from app.services.cloudinary_service import upload_image_to_cloudinary # Thêm service mới
from app.api.v1.deps import get_optional_user
from app.services.detect_limit_service import check_guest_detect_limit

router = APIRouter(tags=["Detection"])

@router.post("/detect")
async def detect_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_optional_user),
    client_key: Optional[str] = Header(default=None, alias="X-Client-Key"),
):
    # Kiểm tra model
    if detector is None:
        raise HTTPException(status_code=500, detail="Model not loaded on server")

    # Đọc dữ liệu file
    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Không đọc được nội dung file")

    # Kiểm tra hạn mức cho khách vãng lai
    if current_user is None:
        if not client_key:
            raise HTTPException(
                status_code=400,
                detail="Thiếu header X-Client-Key cho khách không đăng nhập.",
            )
        check_guest_detect_limit(db, client_key)

    image_url = upload_image_to_cloudinary(raw, folder="zestguard/detections/2025")
    
    if not image_url:
        raise HTTPException(status_code=500, detail="Lỗi khi upload ảnh lên Cloudinary")
    # 2. Chạy nhận diện YOLO
    try:
        yolo_result = detector.predict_bytes(raw_bytes=raw, conf=0.5, iou=0.5)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cannot process image: {e}")

    detections_list = yolo_result.get("detections", [])
    num_detections = yolo_result.get("num_detections", 0)
    explanation = yolo_result.get("explanation")

    # 3. Gọi LLM để tóm tắt và hướng dẫn
    disease_summary, care_instructions = summarize_detections_with_llm(detections_list)

    yolo_result["llm"] = {
        "disease_summary": disease_summary,
        "care_instructions": care_instructions,
    }
    if "explanation" not in yolo_result:
        yolo_result["explanation"] = explanation

    # Phản hồi cho Guest (Không lưu DB)
    # Phản hồi cho Guest (Không lưu DB)
    if current_user is None:
        return JSONResponse({
            "file_name": file.filename,
            "saved_to_db": False,
            "url": image_url, 
            "img": {
                "img_id": None,
                "file_url": image_url, # Key chuẩn để FE hiển thị
                "source_type": "web_upload"
            },
            "num_detections": num_detections,
            "detections": detections_list,
            "explanation": explanation,
            "llm": yolo_result["llm"],
        })

    # 4. Lưu vào DB cho thành viên
    saved = save_detection_result(
        db=db,
        image_url=image_url, # Truyền URL thay vì raw bytes
        filename=file.filename,
        yolo_result=yolo_result,
        user_id=current_user.user_id,
        device_id=None,
        model_version="v1.0",
    )

    return JSONResponse({
        "file_name": file.filename,
        "saved_to_db": True,
        "url": image_url, # URL gốc để dùng nhanh
        "img": {
            "img_id": saved.img_id if hasattr(saved, 'img_id') else None,
            "file_url": image_url, # Key này cực kỳ quan trọng để FE hiển thị ảnh
            "source_type": "web_upload"
        },
        "num_detections": num_detections,
        "detections": detections_list,
        "explanation": explanation,
        "llm": yolo_result["llm"],
    })