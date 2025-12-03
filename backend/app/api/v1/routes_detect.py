# app/api/v1/routes_detect.py
from typing import Optional

from fastapi import APIRouter, UploadFile, File, HTTPException, Depends, Header
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.services.inference_service import detector
from app.services.llm_service import summarize_detections_with_llm
from app.services.detect_service import save_detection_result
from app.api.v1.deps import get_optional_user
from app.services.detect_limit_service import check_guest_detect_limit  # NEW


router = APIRouter(tags=["Detection"])


@router.post("/detect")
async def detect_image(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user=Depends(get_optional_user),
    # đọc header X-Client-Key (frontend đã gửi)
    client_key: Optional[str] = Header(default=None, alias="X-Client-Key"),
):
    if detector is None:
        raise HTTPException(status_code=500, detail="Model not loaded on server")

    raw = await file.read()
    if not raw:
        raise HTTPException(status_code=400, detail="Không đọc được nội dung file")

    # =========================
    # GIỚI HẠN CHO KHÁCH WEB
    # =========================
    if current_user is None:
        # khách mà không gửi client_key -> coi như request không hợp lệ
        if not client_key:
            raise HTTPException(
                status_code=400,
                detail="Thiếu header X-Client-Key cho khách không đăng nhập.",
            )

        # check & tăng count, nếu quá 3 lần/ngày sẽ raise 429
        check_guest_detect_limit(db, client_key)

    # =========================
    # XỬ LÝ DETECT NHƯ CŨ
    # =========================
    try:
        yolo_result = detector.predict_bytes(raw_bytes=raw, conf=0.5, iou=0.5)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Cannot process image: {e}")

    detections_list = yolo_result.get("detections", [])
    num_detections = yolo_result.get("num_detections", 0)
    explanation = yolo_result.get("explanation")

    disease_summary, care_instructions = summarize_detections_with_llm(detections_list)

    # ✅ Chưa đăng nhập → KHÔNG lưu DB
    if current_user is None:
        return JSONResponse({
            "file_name": file.filename,
            "saved_to_db": False,
            "img": None,
            "num_detections": num_detections,
            "detections": detections_list,
            "explanation": explanation,
            "llm": {
                "disease_summary": disease_summary,
                "care_instructions": care_instructions,
            },
        })

    # ✅ Đã đăng nhập → LƯU vào DB
    saved = save_detection_result(
        db=db,
        raw=raw,
        filename=file.filename,
        yolo_result=yolo_result,
        user_id=current_user.user_id,
        device_id=None,              # nếu gắn theo device thì truyền device_id
        model_version="v1.0",
    )

    return JSONResponse({
        "file_name": file.filename,
        "saved_to_db": True,
        "img": saved,   # chứa img_id + file_url
        "num_detections": num_detections,
        "detections": detections_list,
        "explanation": explanation,
        "llm": {
            "disease_summary": disease_summary,
            "care_instructions": care_instructions,
        },
    })
