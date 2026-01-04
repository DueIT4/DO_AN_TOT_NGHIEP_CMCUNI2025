# app/services/detection_history_service.py

from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import desc, or_, func

from app.models.user import Users
from app.models.image_detection import Img, Detection, Disease
from app.schemas.users_devices import DetectionHistoryItem, DetectionHistoryList


class UserNotFoundError(Exception):
    pass


class DetectionNotFoundError(Exception):
    pass


# =============================
# Normalize helpers (STREAM SAFE)
# =============================
def _normalize_file_url(raw: str | None) -> Optional[str]:
    """
    - Cloudinary / URL tuyệt đối -> giữ nguyên
    - Local path -> đảm bảo có /media/
    """
    if not raw:
        return None

    p = raw.strip()
    if not p:
        return None

    if p.startswith(("http://", "https://")):
        return p

    if p.startswith("/media/"):
        return p

    return "/media/" + p.lstrip("/")


def _normalize_confidence(raw) -> Optional[float]:
    if raw is None:
        return None
    try:
        v = float(raw)
    except Exception:
        return None

    if v > 1:
        v = v / 100
    return max(0.0, min(1.0, v))


# ======================================================
# USER HISTORY (1 record / 1 image – STREAM COMPATIBLE)
# ======================================================
def get_detection_history_for_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:
    """
    - 1 ảnh = 1 record
    - Ưu tiên confidence cao nhất
    - Nếu confidence = NULL -> lấy detection mới nhất
    """

    sub_ranked = (
        db.query(
            Detection.img_id.label("img_id"),
            Detection.detection_id.label("det_id"),
            func.row_number()
            .over(
                partition_by=Detection.img_id,
                order_by=[
                    func.coalesce(Detection.confidence, -1).desc(),
                    Detection.detection_id.desc(),
                ],
            )
            .label("rn"),
        )
        .join(Img, Detection.img_id == Img.img_id)
        .filter(Img.user_id == user_id)
        .subquery()
    )

    sub_best = (
        db.query(
            sub_ranked.c.img_id,
            sub_ranked.c.det_id.label("best_det_id"),
        )
        .filter(sub_ranked.c.rn == 1)
        .subquery()
    )

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
        q = q.filter(or_(Img.file_url.ilike(like), Disease.name.ilike(like)))

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
                created_at=img.created_at,
                source_type=img.source_type,  # ✅ STREAM / CAMERA / UPLOAD
            )
        )

    return DetectionHistoryList(items=items, total=total)


# =============================
# ADMIN – ALL USERS
# =============================
def get_detection_history_all_users(
    db: Session,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:

    sub_ranked = (
        db.query(
            Detection.img_id.label("img_id"),
            Detection.detection_id.label("det_id"),
            func.row_number()
            .over(
                partition_by=Detection.img_id,
                order_by=[
                    func.coalesce(Detection.confidence, -1).desc(),
                    Detection.detection_id.desc(),
                ],
            )
            .label("rn"),
        )
        .subquery()
    )

    sub_best = (
        db.query(
            sub_ranked.c.img_id,
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
                Users.email.ilike(like),
                Users.phone.ilike(like),
            )
        )

    total = q.count()
    rows = q.offset(skip).limit(limit).all()

    items: List[DetectionHistoryItem] = []
    for det, img, disease, user in rows:
        items.append(
            DetectionHistoryItem(
                detection_id=int(det.detection_id),
                img_id=int(img.img_id),
                file_url=_normalize_file_url(img.file_url),
                disease_name=disease.name if disease else None,
                confidence=_normalize_confidence(det.confidence),
                created_at=img.created_at,
                source_type=img.source_type,
                user_id=user.user_id if user else None,
                username=user.username if user else None,
                email=user.email if user and "@" in (user.email or "") else None,
                phone=user.phone if user else None,
            )
        )

    return DetectionHistoryList(items=items, total=total)
