
from typing import Optional
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.inference_service import detector
from app.services.llm_service import summarize_detections_with_llm, verify_image_is_plant
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

    # Upload ảnh lên Cloudinary (có fallback)
    image_url = None
    try:
        image_url = upload_image_to_cloudinary(raw, folder="zestguard/detections/2025")
    except Exception as e:
        print(f"Error uploading to Cloudinary: {e}")

    # Nếu upload thất bại, dùng ảnh placeholder để không chặn luồng nhận diện
    if not image_url:
        print("Using placeholder image due to upload failure")
        image_url = "https://placehold.co/600x400?text=Upload+Failed"   

    # 2. Chạy nhận diện YOLO
    try:
        yolo_result = detector.predict_bytes(raw_bytes=raw, conf=0.5, iou=0.5)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cannot process image: {e}")

    detections_list = yolo_result.get("detections", [])
    num_detections = yolo_result.get("num_detections", 0)
    explanation = yolo_result.get("explanation")

    # 🔥 AI CROSS-CHECK: Restore logic (with fixed Client)
    # gemini_says_no = False
    # if detections_list:
    #     is_plant = verify_image_is_plant(raw)
    #     if not is_plant:
    #         gemini_says_no = True
            
    # Logic kết hợp: Gemini là trọng tài chính xác nhất về ngữ cảnh.
    # Nếu Gemini bảo KHÔNG (gemini_says_no), ta sẽ hủy kết quả YOLO trừ khi YOLO cực kỳ chắc chắn (> 98%).
    # Logo hoặc hình vẽ thường bị YOLO nhận nhầm với độ tin cậy cao (85-95%), nên ngưỡng 0.65 cũ quá thấp.
    
    # 🔥 FIX: Tính lại max_conf_check (bị mất ở bước trước)
    # max_conf_check = max((d.get("confidence", 0) for d in detections_list), default=0.0) if detections_list else 0.0

    # if gemini_says_no and max_conf_check < 0.98:
    #         # Gemini bảo KHÔNG phải cây -> Hủy kết quả YOLO
    #         detections_list = []
    #         num_detections = 0
    #         explanation = "Không phát hiện bệnh cây trồng trên ảnh (Ảnh không hợp lệ), vui lòng chụp lại."
    #         yolo_result["detections"] = []
    #         yolo_result["num_detections"] = 0
    #         yolo_result["explanation"] = explanation

    # 3. Gọi LLM để tóm tắt và hướng dẫn (Chỉ gọi nếu confidence >= 0.4)
    max_conf = 0.0
    best_disease = "Không xác định"
    
    if detections_list:
        # Sắp xếp giảm dần theo confidence
        detections_list.sort(key=lambda x: x.get("confidence", 0), reverse=True)
        top = detections_list[0]
        max_conf = top.get("confidence", 0)
        best_disease = top.get("class_name", "Không xác định")

    if max_conf < 0.4:
         disease_summary = "Không phát hiện bệnh cây trồng trên ảnh, vui lòng chụp lại."
         care_instructions = "Vui lòng chụp lại ảnh rõ nét, đúng chủ thể (lá/quả) và đủ sáng."
    else:
         disease_summary, care_instructions = summarize_detections_with_llm(detections_list)

    yolo_result["llm"] = {
        "disease_summary": disease_summary,
        "care_instructions": care_instructions,
    }
    if "explanation" not in yolo_result:
        yolo_result["explanation"] = explanation

    response_data = {
        "file_name": file.filename,
        "saved_to_db": False,
        "url": image_url, 
        "img": {
            "img_id": None,
            "file_url": image_url,
            "source_type": "web_upload"
        },
        "num_detections": num_detections,
        "detections": detections_list,
        "explanation": explanation,
        "llm": yolo_result["llm"],
        # ✅ FE Mobile cần 2 trường này ở root để hiển thị ngay
        "disease_name": best_disease,
        "confidence": max_conf
    }

    # Phản hồi cho Guest (Không lưu DB)
    if current_user is None:
        return JSONResponse(response_data)

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

    response_data["saved_to_db"] = True
    response_data["img"]["img_id"] = saved.img_id if hasattr(saved, 'img_id') else None
    
    return JSONResponse(response_data)