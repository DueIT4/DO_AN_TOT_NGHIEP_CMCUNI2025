from typing import List, Optional

from sqlalchemy.orm import Session
from sqlalchemy import desc, or_

from app.models.user import Users
from app.models.image_detection import Img, Detection, Disease
from app.schemas.users_devices import DetectionHistoryItem, DetectionHistoryList


class UserNotFoundError(Exception):
    """Raised when user does not exist."""
    pass


class DetectionNotFoundError(Exception):
    """Raised when detection record does not exist or does not belong to user."""
    pass


def _build_history_query(
    db: Session,
    user_id: int,
    search: Optional[str] = None,
):
    """
    Tạo query chung để lấy lịch sử dự đoán của 1 user.
    """
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


def get_detection_history_for_user(
    db: Session,
    user_id: int,
    skip: int = 0,
    limit: int = 50,
    search: Optional[str] = None,
) -> DetectionHistoryList:
    """
    Lấy lịch sử dự đoán cho 1 user (đã chắc chắn tồn tại).
    """
    q = _build_history_query(db=db, user_id=user_id, search=search)

    total = q.count()
    rows = q.offset(skip).limit(limit).all()

    items: List[DetectionHistoryItem] = []
    for det, img, disease in rows:
        items.append(
            DetectionHistoryItem(
                detection_id=det.detection_id,
                img_id=img.img_id,
                file_url=img.file_url,
                disease_name=disease.name if disease else None,
                confidence=float(det.confidence)
                if det.confidence is not None
                else None,
                created_at=det.created_at,
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
    """
    Dùng cho case admin xem lịch sử của user khác.
    Kiểm tra user tồn tại, nếu không → UserNotFoundError.
    """
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


def delete_detection_of_user(
    db: Session,
    detection_id: int,
    owner_user_id: int,
) -> None:
    """
    Xoá 1 detection nhưng phải thuộc về owner_user_id.
    Nếu không tìm thấy → DetectionNotFoundError.
    """
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
