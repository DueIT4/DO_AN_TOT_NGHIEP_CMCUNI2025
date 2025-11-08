from pathlib import Path
from uuid import uuid4
from fastapi import APIRouter, UploadFile, File, HTTPException, Depends
from sqlalchemy.orm import Session
from sqlalchemy import select
import shutil

from app.services.inference_service import InferenceService
from app.services.llm_service import LLMService
from app.core.db import get_db
from app.models.img import Img, SourceType
from app.models.diseases import Disease
from app.models.detections import Detection, ReviewStatus
from app.schemas.detect import DetectExplainResp
from app.api.v1.deps import get_current_user, auth_scheme
from app.models.user import Users
from typing import Optional
from fastapi.security import HTTPAuthorizationCredentials

router = APIRouter(prefix="/detect", tags=["Detection"])

# Khởi tạo services
inference_service = InferenceService()
llm_service = LLMService()

# Thư mục lưu ảnh upload
UPLOAD_DIR = Path("media/uploads")
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


def get_optional_user(
    creds: Optional[HTTPAuthorizationCredentials] = Depends(auth_scheme),
    db: Session = Depends(get_db)
) -> Optional[Users]:
    """Lấy user nếu có token, không thì trả về None."""
    if not creds or creds.scheme.lower() != "bearer":
        return None
    try:
        from app.services.auth_jwt import decode_access_token
        payload = decode_access_token(creds.credentials)
        uid = int(payload["uid"])
        user = db.scalar(select(Users).where(Users.user_id == uid))
        return user
    except Exception:
        return None


@router.post("/upload", response_model=DetectExplainResp)
async def detect_image(
    image: UploadFile = File(...),
    db: Session = Depends(get_db),
    current_user: Optional[Users] = Depends(get_optional_user)  # Tùy chọn: có thể không cần đăng nhập
):
    """
    Upload ảnh, chạy inference, sinh giải thích LLM và lưu vào database.
    
    Flow:
    1. Lưu ảnh vào disk
    2. Tạo record Img trong DB
    3. Chạy inference để lấy tên bệnh và độ chính xác
    4. Sinh giải thích bằng LLM
    5. Tìm hoặc tạo Disease record
    6. Tạo Detection record
    7. Trả về kết quả
    """
    try:
        # 1. Kiểm tra file ảnh
        if not image.content_type or not image.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File phải là ảnh")
        
        # 2. Đọc dữ liệu ảnh vào memory
        image_data = await image.read()
        if len(image_data) == 0:
            raise HTTPException(status_code=400, detail="File ảnh rỗng")
        
        # 3. Lưu ảnh vào disk
        ext = Path(image.filename).suffix.lower() if image.filename else ".jpg"
        if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
            ext = ".jpg"
        
        fname = f"{uuid4().hex}{ext}"
        save_path = UPLOAD_DIR / fname
        file_url = f"/media/uploads/{fname}"
        
        # Lưu file
        with save_path.open("wb") as f:
            f.write(image_data)
        
        # 4. Tạo record Img trong DB
        img_record = Img(
            source_type=SourceType.upload,
            user_id=current_user.user_id if current_user else None,
            device_id=None,  # Có thể thêm sau nếu cần
            file_url=file_url
        )
        db.add(img_record)
        db.flush()  # Để lấy img_id
        
        # 5. Chạy inference (sử dụng dữ liệu đã đọc)
        from fastapi import UploadFile as FastAPIUploadFile
        from io import BytesIO
        
        # Tạo UploadFile tạm để truyền vào inference service
        temp_upload = FastAPIUploadFile(
            filename=image.filename or "image.jpg",
            file=BytesIO(image_data)
        )
        
        inference_result = await inference_service.analyze(temp_upload)
        disease_name = inference_result["disease"]
        confidence = inference_result["confidence"]
        model_version = inference_result.get("model_version", "v1.0")
        
        # 6. Sinh giải thích bằng LLM
        explanation = await llm_service.generate_explanation(disease_name, confidence)
        
        # 7. Tìm hoặc tạo Disease record
        disease = db.scalar(select(Disease).where(Disease.name == disease_name))
        if not disease:
            # Tạo mới disease nếu chưa có
            disease = Disease(
                name=disease_name,
                description=explanation[:500] if len(explanation) > 500 else explanation,  # Lưu phần đầu
                treatment_guideline=explanation  # Lưu toàn bộ vào treatment_guideline
            )
            db.add(disease)
            db.flush()  # Để lấy disease_id
        
        disease_id = disease.disease_id if disease else None
        
        # 8. Tạo Detection record
        detection = Detection(
            img_id=img_record.img_id,
            disease_id=disease_id,
            confidence=float(confidence),
            description=explanation,
            treatment_guideline=explanation,  # Có thể tách riêng nếu cần
            review_status=ReviewStatus.pending,
            model_version=model_version
        )
        db.add(detection)
        db.commit()
        db.refresh(detection)
        db.refresh(img_record)
        
        # 9. Trả về kết quả
        return DetectExplainResp(
            disease=disease_name,
            confidence=float(confidence),
            explanation=explanation,
            img_id=img_record.img_id,
            detection_id=detection.detection_id
        )
        
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Lỗi khi xử lý ảnh: {str(e)}")
