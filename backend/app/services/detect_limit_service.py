# app/services/detect_limit_service.py
from datetime import date
from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.models.detect_usage import DetectUsage

MAX_GUEST_DETECT_PER_DAY = 3


def check_guest_detect_limit(db: Session, client_key: str) -> None:
    """
    Giới hạn số lần gọi /detect cho KHÁCH (không đăng nhập)
    theo client_key + ngày.
    """
    today = date.today()

    usage = (
        db.query(DetectUsage)
        .filter_by(client_key=client_key, date=today)
        .first()
    )

    if usage:
        if usage.count >= MAX_GUEST_DETECT_PER_DAY:
            # Trả về HTTP 429, frontend sẽ hiển thị popup tải app
            raise HTTPException(
                status_code=429,
                detail={
                    "code": "LIMIT_REACHED",
                    "message": (
                        "Bạn đã dùng hết 3 lượt chẩn đoán miễn phí trên web hôm nay. "
                        "Vui lòng tải ứng dụng ZestGuard trên CH Play để tiếp tục sử dụng không giới hạn."
                    ),
                },
            )
        usage.count += 1
        db.commit()
        return

    # Chưa có record hôm nay -> tạo mới
    usage = DetectUsage(
        client_key=client_key,
        date=today,
        count=1,
    )
    db.add(usage)
    db.commit()
