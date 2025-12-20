from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import select, desc

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.notification import Notifications
from app.schemas.notification import (
    NotificationCreate, NotificationOut, NotificationWithUser, NotificationResend
)
from app.services.permissions import require_perm

router = APIRouter(prefix="/notifications", tags=["notifications"])

# ========== CREATE (admin, support_admin) ==========
@router.post(
    "/create",
    status_code=status.HTTP_201_CREATED,
    response_model=list[NotificationOut],
    dependencies=[Depends(require_perm("noti:create"))],
)
def create_notifications(
    payload: NotificationCreate,
    db: Session = Depends(get_db),
    sender: Users = Depends(get_current_user),
):
    if not payload.send_all and not payload.user_ids:
        raise HTTPException(status_code=400, detail="Phải chọn user_ids hoặc send_all=true")

    if payload.send_all:
        recipients = db.scalars(select(Users).where(Users.status == "active")).all()
    else:
        recipients = db.scalars(select(Users).where(Users.user_id.in_(payload.user_ids))).all()

    if not recipients:
        raise HTTPException(status_code=404, detail="Không tìm thấy người nhận phù hợp")

    rows = [
        Notifications(
            user_id=u.user_id,
            title=payload.title,
            description=payload.description,
            sender_id=sender.user_id,
        )
        for u in recipients
    ]
    db.add_all(rows)
    db.commit()

    out = []
    for r in rows:
      db.refresh(r)
      out.append(r)
    return out

# ========== RESEND (admin, support_admin) ==========
@router.post(
    "/{notification_id}/resend",
    status_code=status.HTTP_201_CREATED,
    response_model=list[NotificationOut],
    dependencies=[Depends(require_perm("noti:create"))],
)
def resend_notification(
    notification_id: int,
    payload: NotificationResend,
    db: Session = Depends(get_db),
    sender: Users = Depends(get_current_user),
):
    old = db.get(Notifications, notification_id)
    if not old:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo gốc")

    if not payload.send_all and not payload.user_ids:
        raise HTTPException(status_code=400, detail="Phải chọn user_ids hoặc send_all=true")

    if payload.send_all:
        recipients = db.scalars(select(Users).where(Users.status == "active")).all()
    else:
        recipients = db.scalars(select(Users).where(Users.user_id.in_(payload.user_ids))).all()

    if not recipients:
        raise HTTPException(status_code=404, detail="Không tìm thấy người nhận phù hợp")

    rows = [
        Notifications(
            user_id=u.user_id,
            title=old.title,
            description=old.description,
            sender_id=sender.user_id,
            resend_of=old.notification_id,  # tracking
        )
        for u in recipients
    ]
    db.add_all(rows)
    db.commit()

    out = []
    for r in rows:
        db.refresh(r)
        out.append(r)
    return out

# ========== LIST SENT (admin, support_admin) ==========
@router.get(
    "/sent",
    response_model=list[NotificationWithUser],
    dependencies=[Depends(require_perm("noti:list"))],
)
def list_sent(db: Session = Depends(get_db)):
    stmt = (
        select(
            Notifications,
            Users.username,
            Users.email
        )
        .join(Users, Notifications.user_id == Users.user_id)
        .order_by(desc(Notifications.created_at))
    )

    result: list[NotificationWithUser] = []
    for n, username, email in db.execute(stmt).all():
        result.append(
            NotificationWithUser(
                notification_id=n.notification_id,
                user_id=n.user_id,
                title=n.title,
                description=n.description,
                created_at=n.created_at,
                read_at=n.read_at,
                username=username,
                email=email,
                resend_of=n.resend_of,
            )
        )
    return result

# ========== LIST MY (user) ==========
@router.get("/my", response_model=list[NotificationOut])
def list_my_notifications(
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    rows = db.scalars(
        select(Notifications)
        .where(Notifications.user_id == user.user_id)
        .order_by(desc(Notifications.created_at))
    ).all()
    return rows

# ========== MARK READ (user) ==========
@router.patch("/{notification_id}/read", response_model=NotificationOut)
def mark_read(
    notification_id: int,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    n = db.get(Notifications, notification_id)
    if not n or n.user_id != user.user_id:
        raise HTTPException(status_code=404, detail="Không tìm thấy thông báo")

    if n.read_at is None:
        from sqlalchemy.sql import func
        n.read_at = db.scalar(select(func.now()))
        db.commit()
        db.refresh(n)
    return n

# ========== /me (user) - có sender_name ==========
@router.get("/me", response_model=list[NotificationOut])
def my_notifications(
    db: Session = Depends(get_db),
    current_user: Users = Depends(get_current_user),
):
    rows = (
        db.query(Notifications)
        .filter(Notifications.user_id == current_user.user_id)
        .order_by(desc(Notifications.created_at))
        .all()
    )

    result: list[NotificationOut] = []
    for n in rows:
        result.append(
            NotificationOut(
                notification_id=n.notification_id,
                title=n.title,
                description=n.description,
                created_at=n.created_at,
                read_at=n.read_at,
                sender_id=n.sender_id,
                sender_name=n.sender.username if n.sender else None,
                resend_of=n.resend_of,
            )
        )
    return result
