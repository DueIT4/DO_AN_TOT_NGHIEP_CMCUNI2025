from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.schemas.users_devices import DetectionHistoryList
from app.services.detection_history_service import (
    get_detection_history_for_user,
    get_detection_history_for_existing_user,
    delete_detection_of_user,
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
    return get_detection_history_for_user(
        db=db,
        user_id=current_user.user_id,
        skip=skip,
        limit=limit,
        search=search,
    )


# 2) Admin xem lịch sử dự đoán của 1 user bất kỳ
@router.get("/users/{user_id}", response_model=DetectionHistoryList)
def detection_history_for_user(
    user_id: int,
    db: Session = Depends(get_db),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    search: Optional[str] = Query(None, min_length=1),
):
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


# 3) Xoá 1 bản ghi lịch sử của chính current user
@router.delete("/{detection_id}", status_code=204)
def delete_my_detection(
    detection_id: int,
    db: Session = Depends(get_db),
    current_user=Depends(get_current_user),
):
    try:
        delete_detection_of_user(
            db=db,
            detection_id=detection_id,
            owner_user_id=current_user.user_id,
        )
    except DetectionNotFoundError:
        raise HTTPException(status_code=404, detail="Detection không tồn tại")

    # 204 No Content – không cần return gì
