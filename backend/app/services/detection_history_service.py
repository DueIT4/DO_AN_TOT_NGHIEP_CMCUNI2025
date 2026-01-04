# app/services/detection_history_service.py

from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_, func, and_

from app.models.user import Users
from app.models.image_detection import Img, Detection, Disease
from app.schemas.users_devices import DetectionHistoryItem, DetectionHistoryList


class UserNotFoundError(Exception):
    pass


class DetectionNotFoundError(Exception):
    pass


def _normalize_file_url(raw: str | None) -> Optional[str]:
    """
    Chuẩn hóa file_url:
    - None => None
    - "" => None
    - "detections/2025/..." => "/media/detections/2025/..."
    - "/media/detections/..." => giữ nguyên
    """
    if not raw:
        return None
    p = raw.strip()
    if not p:
        return None
    if p.startswith("/media/"):
        return p
    return "/media/" + p.lstrip("/")


def _normalize_confidence(raw) -> Optional[float]:
    """
    Trả về confidence 0..1 cho FE
    - DB có thể đang lưu 0..100 (Numeric) -> chia 100
    - hoặc đã là 0..1 -> giữ nguyên
    """
    if raw is None:
        return None
    try:
        v = float(raw)
    except Exception:
        return None

    if v > 1.0:
        v = v / 100.0
    if v < 0:
        v = 0.0
    if v > 1:
        v = 1.0
    return v


# ============================================
# Lịch sử của USER hiện tại (✅ 1 item / 1 img)
# ============================================
def get_detection_history_for_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:
    """
    FIX: Trả 1 record lịch sử cho mỗi Img (mỗi ảnh).
    - Ưu tiên detection có confidence cao nhất
    - Nếu tất cả detection đều có confidence = None, lấy detection mới nhất
    """

    # Subquery: chọn 1 detection_id cho mỗi img_id
    # Sắp xếp theo: confidence DESC NULLS LAST, detection_id DESC
    # Lấy detection_id đầu tiên (confidence cao nhất hoặc mới nhất nếu confidence = None)
    from sqlalchemy import distinct
    from sqlalchemy.sql import func as sql_func
    from sqlalchemy.orm import aliased

    # Subquery: lấy detection_id tốt nhất cho mỗi img
    # COALESCE để đưa NULL về -1 khi sắp xếp
    sub_ranked = (
        db.query(
            Detection.img_id.label("img_id"),
            Detection.detection_id.label("det_id"),
            sql_func.row_number()
            .over(
                partition_by=Detection.img_id,
                order_by=[
                    sql_func.coalesce(Detection.confidence, -1).desc(),
                    Detection.detection_id.desc(),
                ],
            )
            .label("rn"),
        )
        .join(Img, Detection.img_id == Img.img_id)
        .filter(Img.user_id == user_id)
        .subquery()
    )

    # Chỉ lấy rn = 1
    sub_best = (
        db.query(
            sub_ranked.c.img_id.label("img_id"),
            sub_ranked.c.det_id.label("best_det_id"),
        )
        .filter(sub_ranked.c.rn == 1)
        .subquery()
    )

    # Query chính
    q = (
        db.query(Detection, Img, Disease)
        .join(sub_best, Detection.detection_id == sub_best.c.best_det_id)
        .join(Img, Detection.img_id == Img.img_id)
        .outerjoin(Disease, Detection.disease_id == Disease.disease_id)
        .filter(Img.user_id == user_id)
        .order_by(desc(Img.created_at))
    )

    if search:
        like = f"%{search}%"
        q = q.filter(
            or_(
                Img.file_url.ilike(like),
                Disease.name.ilike(like),
            )
        )

    total = q.count()
    rows = q.offset(skip).limit(limit).all()

    items: List[DetectionHistoryItem] = []
    for det, img, disease in rows:
        items.append(
            DetectionHistoryItem(
                detection_id=int(det.detection_id),
                img_id=int(img.img_id),
                file_url=_normalize_file_url(img.file_url),
                disease_name=disease.name if disease else None,
                confidence=_normalize_confidence(det.confidence),
                created_at=img.created_at,  # ✅ dùng created_at của ảnh để ổn định
                source_type=img.source_type,  # ✅ Thêm source_type
            )
        )

    return DetectionHistoryList(items=items, total=total)


def get_detection_history_for_existing_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:
    user = db.get(Users, user_id)
    if not user:
        raise UserNotFoundError(f"User {user_id} not found")

    return get_detection_history_for_user(
        db=db,
        user_id=user_id,
        skip=skip,
        limit=limit,
        search=search,
    )


def get_detection_history_all_users(
    db: Session,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:
    """
    Lịch sử tất cả user (admin).
    FIX: Hỗ trợ detection có confidence = None (unknown).
    """
    from sqlalchemy.sql import func as sql_func

    # Subquery: chọn detection_id tốt nhất cho mỗi img (tất cả user)
    sub_ranked = (
        db.query(
            Detection.img_id.label("img_id"),
            Detection.detection_id.label("det_id"),
            sql_func.row_number()
            .over(
                partition_by=Detection.img_id,
                order_by=[
                    sql_func.coalesce(Detection.confidence, -1).desc(),
                    Detection.detection_id.desc(),
                ],
            )
            .label("rn"),
        )
        .subquery()
    )

    sub_best = (
        db.query(
            sub_ranked.c.img_id.label("img_id"),
            sub_ranked.c.det_id.label("best_det_id"),
        )
        .filter(sub_ranked.c.rn == 1)
        .subquery()
    )

    q = (
        db.query(Detection, Img, Disease, Users)
        .join(sub_best, Detection.detection_id == sub_best.c.best_det_id)
        .join(Img, Detection.img_id == Img.img_id)
        .outerjoin(Disease, Detection.disease_id == Disease.disease_id)
        .outerjoin(Users, Img.user_id == Users.user_id)
        .order_by(desc(Img.created_at))
    )

    if search:
        like = f"%{search}%"
        q = q.filter(
            or_(
                Img.file_url.ilike(like),
                Disease.name.ilike(like),
                Users.username.ilike(like),
                Users.phone.ilike(like),
                Users.email.ilike(like),
            )
        )

    total = q.count()
    rows = q.offset(skip).limit(limit).all()

    items: List[DetectionHistoryItem] = []
    for det, img, disease, user in rows:
        safe_email = None
        username = None
        phone = None
        uid = None
        if user:
            raw_email = (user.email or "").strip()
            safe_email = raw_email if "@" in raw_email else None
            username = user.username
            phone = user.phone
            uid = user.user_id

        items.append(
            DetectionHistoryItem(
                detection_id=int(det.detection_id),
                img_id=int(img.img_id),
                file_url=_normalize_file_url(img.file_url),
                disease_name=disease.name if disease else None,
                confidence=_normalize_confidence(det.confidence),
                created_at=img.created_at,
                source_type=img.source_type,  # ✅ Thêm source_type
                user_id=uid,
                username=username,
                email=safe_email,
                phone=phone,
            )
        )

    return DetectionHistoryList(items=items, total=total)


def delete_detection_of_user(
    db: Session,
    detection_id: int,
    owner_user_id: int,
) -> None:
    det = (
        db.query(Detection)
        .join(Img, Detection.img_id == Img.img_id)
        .filter(
            Detection.detection_id == detection_id,
            Img.user_id == owner_user_id,
        )
        .first()
    )

    if not det:
        raise DetectionNotFoundError(
            f"Detection {detection_id} not found for user {owner_user_id}"
        )

    db.delete(det)
    db.commit()


def delete_detection_any(db: Session, detection_id: int) -> None:
    det = db.get(Detection, detection_id)
    if not det:
        raise DetectionNotFoundError(f"Detection {detection_id} not found")
    db.delete(det)
    db.commit()
