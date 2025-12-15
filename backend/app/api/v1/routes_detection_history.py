# app/api/v1/routes_detection_history.py
from typing import Optional
from app.services.export_dataset_service import export_detection_to_dataset, ExportError
from app.models.image_detection import Img, Detection, Disease

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.role import RoleType
from app.schemas.users_devices import DetectionHistoryList
from app.services.detection_history_service import (
    get_detection_history_for_user,
    get_detection_history_for_existing_user,
    get_detection_history_all_users,
    delete_detection_of_user,
    delete_detection_any,
    UserNotFoundError,
    DetectionNotFoundError,
)

router = APIRouter(
    prefix="/detection-history",
    tags=["Detection History"],
)


# 1) Lịch sử dự đoán của *current user*
@router.get("/me", response_model=DetectionHistoryList)
def my_detection_history(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None, min_length=1),
):
    """
    Lịch sử detect của chính user đang đăng nhập.
    """
    return get_detection_history_for_user(
        db=db,
        user_id=current_user.user_id,
        skip=skip,
        limit=limit,
        search=search,
    )


# 2) ADMIN xem lịch sử dự đoán của 1 user bất kỳ
@router.get("/users/{user_id}", response_model=DetectionHistoryList)
def detection_history_for_user(
    user_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None, min_length=1),
):
    """
    Chỉ admin / support_admin được xem lịch sử của user khác.
    """
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được xem lịch sử của người dùng khác",
        )

    try:
        return get_detection_history_for_existing_user(
            db=db,
            user_id=user_id,
            skip=skip,
            limit=limit,
            search=search,
        )
    except UserNotFoundError:
        raise HTTPException(status_code=404, detail="User không tồn tại")


# 3) ADMIN: lịch sử dự đoán của TẤT CẢ người dùng
@router.get("/admin", response_model=DetectionHistoryList)
def admin_detection_history(
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None, min_length=1),
):
    """
    Admin / support_admin xem toàn bộ lịch sử detect của tất cả user.
    """
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được xem toàn bộ lịch sử",
        )

    return get_detection_history_all_users(
        db=db,
        skip=skip,
        limit=limit,
        search=search,
    )


# 4) Xoá 1 bản ghi lịch sử của chính current user
@router.delete("/{detection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_my_detection(
    detection_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    User tự xoá lịch sử detect của chính mình.
    """
    try:
        delete_detection_of_user(
            db=db,
            detection_id=detection_id,
            owner_user_id=current_user.user_id,
        )
    except DetectionNotFoundError:
        raise HTTPException(status_code=404, detail="Detection không tồn tại")

    # 204 No Content – không cần return body
    return


# 5) ADMIN xoá bất kỳ detection nào
@router.delete("/admin/{detection_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_detection_admin(
    detection_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    """
    Admin / support_admin được phép xoá bất kỳ detection nào.
    """
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Chỉ admin mới được xoá lịch sử của người khác",
        )

    try:
        delete_detection_any(db=db, detection_id=detection_id)
    except DetectionNotFoundError:
        raise HTTPException(status_code=404, detail="Detection không tồn tại")

    return
@router.post("/{detection_id}/export-train")
def export_detection_train(
    detection_id: int,
    db: Session = Depends(get_db),
    current_user = Depends(get_current_user),
):
    """
    Từ lịch sử dự đoán, bấm 'Lưu làm data train' cho 1 detection.
    - Admin/support_admin: export được mọi lịch sử.
    - User thường: chỉ export được lịch sử của chính mình.
    """
    det = db.get(Detection, detection_id)
    if not det:
        raise HTTPException(status_code=404, detail="Detection không tồn tại")

    img = db.get(Img, det.img_id)
    if not img:
        raise HTTPException(status_code=404, detail="Ảnh không tồn tại")

    # Quyền
    if current_user.role_type not in (RoleType.admin, RoleType.support_admin):
        if img.user_id != current_user.user_id:
            raise HTTPException(
                status_code=403,
                detail="Bạn không có quyền export detection của người khác",
            )

    try:
        saved_files = export_detection_to_dataset(
            db=db,
            detection_id=detection_id,
            split="train",
        )
    except ExportError as e:
        raise HTTPException(status_code=400, detail=str(e))

    return {"success": True, "saved_files": saved_files}
@router.get("/me/{detection_id}")
def my_detection_history_detail(
    detection_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    # 1) tìm detection
    det: Detection | None = db.get(Detection, detection_id)
    if not det:
        raise HTTPException(status_code=404, detail="Detection không tồn tại")

    # 2) tìm ảnh và check quyền
    img: Img | None = db.get(Img, det.img_id)
    if not img:
        raise HTTPException(status_code=404, detail="Ảnh không tồn tại")

    # user thường chỉ được xem của mình
    if img.user_id != current_user.user_id:
        raise HTTPException(status_code=403, detail="Bạn không có quyền xem bản ghi này")

    # 3) lấy disease name (nếu có)
    disease: Disease | None = db.get(Disease, det.disease_id) if det.disease_id else None
    disease_name = disease.name if disease and disease.name else "Không xác định"

    # 4) lấy tất cả detections của cùng 1 ảnh (để show bbox list)
    rows = (
        db.query(Detection, Disease)
        .join(Disease, Detection.disease_id == Disease.disease_id, isouter=True)
        .filter(Detection.img_id == det.img_id)
        .order_by(Detection.created_at.desc())
        .all()
    )

    detections_payload = []
    # 4) detections_payload
    for d, dis in rows:
        name = dis.name if dis and dis.name else "Không xác định"
        conf = float(d.confidence or 0.0)   # ✅ bỏ /100
        detections_payload.append({
            "detection_id": int(d.detection_id),
            "class_name": name,
            "confidence": float(conf),
            "bbox": d.bbox,
            "model_version": d.model_version,
            "created_at": d.created_at,
            "description": d.description,
            "treatment_guideline": d.treatment_guideline,
        })

    # 5) payload tổng
    confidence = float(det.confidence or 0.0)  # ✅ bỏ /100


    return {
        "detection_id": int(det.detection_id),
        "created_at": det.created_at,
        "img_id": int(img.img_id),
        "img_url": img.file_url,
        "source_type": img.source_type,
        "device_id": int(img.device_id) if img.device_id is not None else None,

        "disease_name": disease_name,
        "confidence": float(confidence),

        # ✅ 2 field này FE dùng để hiển thị “Giải thích” và “Khuyến nghị”
        "description": det.description,
        "treatment_guideline": det.treatment_guideline,

        # ✅ list detections để hiển thị “Chi tiết phát hiện”
        "detections": detections_payload,
    }


    