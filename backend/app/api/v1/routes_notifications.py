from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, or_, update
from typing import List

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.notification import Notification
from app.schemas.notification import NotificationCreate, NotificationOut, NotificationWithUser
from app.services.permissions import require_perm

router = APIRouter(prefix="/notifications", tags=["notifications"])

# ========== CREATE (admin, support_admin) ==========
@router.post("/create", status_code=status.HTTP_201_CREATED, response_model=List[NotificationOut],
             dependencies=[Depends(require_perm("noti:create"))])
def create_notifications(payload: NotificationCreate, 
                         db: Session = Depends(get_db),
                         sender: Users = Depends(get_current_user)):
    # Ràng buộc: phải có user_ids hoặc send_all
    if not payload.send_all and not payload.user_ids:
        raise HTTPException(status_code=400, detail="Phải chọn user_ids hoặc send_all=true")

    # Tập người nhận
    recipients = []
    if payload.send_all:
        recipients = db.scalars(
            select(Users).where(Users.status == "active")  # hoặc bỏ điều kiện tuỳ bạn
        ).all()
    else:
        recipients = db.scalars(
            select(Users).where(Users.user_id.in_(payload.user_ids))
        ).all()

    if not recipients:
        raise HTTPException(status_code=404, detail="Không tìm thấy người nhận phù hợp")

    # Tạo thông báo: 1 row / 1 người nhận
    rows = []
    for u in recipients:
        rows.append(Notification(
            user_id=u.user_id,
            title=payload.title,
            description=payload.description,
            #sender_id=sender.user_id
        ))
    db.add_all(rows)
    db.commit()

    # refresh nhanh để trả về id (ít tốn kém)
    out = []
    for r in rows:
        db.refresh(r)
        out.append(r)
    return out

# ========== LIST SENT (admin, support_admin) ==========
@router.get("/sent", response_model=List[NotificationWithUser],
            dependencies=[Depends(require_perm("noti:list"))])
def list_sent(db: Session = Depends(get_db)):
    # Liệt kê tất cả thông báo đã gửi, kèm tên/email người nhận
    result = []
    stmt = select(Notification, Users.username, Users.email).join(Users, Notification.user_id == Users.user_id)
    for n, username, email in db.execute(stmt).all():
        result.append(NotificationWithUser(
            notification_id=n.notification_id,
            user_id=n.user_id,
            title=n.title,
            description=n.description,
            created_at=n.created_at,
            read_at=n.read_at,
            username=username,
            email=email
        ))
    return result

# ========== LIST MY (user) ==========
@router.get("/my", response_model=List[NotificationOut])
def list_my_notifications(db: Session = Depends(get_db), user: Users = Depends(get_current_user)):
    try:
        rows = db.scalars(
            select(Notification).where(Notification.user_id == user.user_id).order_by(Notification.created_at.desc())
        ).all()
        return rows
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi khi lấy thông báo: {str(e)}")

# ========== MARK READ (user) ==========
@router.patch("/{notification_id}/read", response_model=NotificationOut)
def mark_read(notification_id: int, db: Session = Depends(get_db), user: Users = Depends(get_current_user)):
    n = db.get(Notification, notification_id)
    if not n or n.user_id != user.user_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo")
    if n.read_at is None:
        from sqlalchemy.sql import func
        n.read_at = db.scalar(select(func.now()))
        db.commit()
        db.refresh(n)
    return n

# ========== DELETE (admin, support_admin) ==========
@router.delete("/{notification_id}/delete", status_code=status.HTTP_204_NO_CONTENT,
               dependencies=[Depends(require_perm("noti:delete"))])
def delete_notification(notification_id: int, db: Session = Depends(get_db)):
    n = db.get(Notification, notification_id)
    if not n:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo")
    db.delete(n)
    db.commit()
    return {"ok": True}
