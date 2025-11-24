# app/services/detection_history_service.py

from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_

from app.models.user import Users
from app.models.image_detection import Img, Detection, Disease
from app.schemas.users_devices import DetectionHistoryItem, DetectionHistoryList


class UserNotFoundError(Exception):
    pass


class DetectionNotFoundError(Exception):
    pass


# ============================================
# 🔧 Chuẩn hóa đường dẫn file_url
# ============================================
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


# ============================================
# Query chung
# ============================================
def _build_history_query(
    db: Session,
    user_id: int,
    search: Optional[str] = None,
):
    q = (
        db.query(Detection, Img, Disease)
        .join(Img, Detection.img_id == Img.img_id)
        .outerjoin(Disease, Detection.disease_id == Disease.disease_id)
        .filter(Img.user_id == user_id)
        .order_by(desc(Detection.created_at))
    )

    if search:
        like = f"%{search}%"
        q = q.filter(
            or_(
                Img.file_url.ilike(like),
                Disease.name.ilike(like),
            )
        )

    return q


# ============================================
# Lịch sử của USER hiện tại
# ============================================
def get_detection_history_for_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:

    q = _build_history_query(db=db, user_id=user_id, search=search)

    total = q.count()
    rows = q.offset(skip).limit(limit).all()

    items: List[DetectionHistoryItem] = []

    for det, img, disease in rows:
        items.append(
            DetectionHistoryItem(
                detection_id=det.detection_id,
                img_id=img.img_id,
                file_url=_normalize_file_url(img.file_url),  # <<< IMPORTANT
                disease_name=disease.name if disease else None,
                confidence=float(det.confidence) if det.confidence is not None else None,
                created_at=det.created_at,
            )
        )

    return DetectionHistoryList(items=items, total=total)


# ============================================
# Admin xem lịch sử của 1 USER cụ thể
# ============================================
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


# ============================================
# Admin xem TẤT CẢ lịch sử của mọi user
# ============================================
def get_detection_history_all_users(
    db: Session,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:

    q = (
        db.query(Detection, Img, Disease, Users)
        .join(Img, Detection.img_id == Img.img_id)
        .outerjoin(Disease, Detection.disease_id == Disease.disease_id)
        .outerjoin(Users, Img.user_id == Users.user_id)
        .order_by(desc(Detection.created_at))
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

        # user có thể None
        if user:
            raw_email = (user.email or "").strip()
            safe_email = raw_email if "@" in raw_email else None
            user_id = user.user_id
            username = user.username
            phone = user.phone
        else:
            safe_email = None
            user_id = None
            username = None
            phone = None

        items.append(
            DetectionHistoryItem(
                detection_id=det.detection_id,
                img_id=img.img_id,
                file_url=_normalize_file_url(img.file_url),   # <<< FIXED
                disease_name=disease.name if disease else None,
                confidence=float(det.confidence) if det.confidence is not None else None,
                created_at=det.created_at,
                user_id=user_id,
                username=username,
                email=safe_email,
                phone=phone,
            )
        )

    return DetectionHistoryList(items=items, total=total)


# ============================================
# Xoá detection của CHÍNH USER
# ============================================
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


# ============================================
# Admin xoá bất kỳ detection
# ============================================
def delete_detection_any(
    db: Session,
    detection_id: int,
) -> None:

    det = db.get(Detection, detection_id)
    if not det:
        raise DetectionNotFoundError(f"Detection {detection_id} not found")

    db.delete(det)
    db.commit()
