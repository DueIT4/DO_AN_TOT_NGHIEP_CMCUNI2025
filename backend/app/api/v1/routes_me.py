from fastapi import APIRouter, Depends, HTTPException, status, Form
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.services.permissions import require_perm
from app.models.user import Users
from app.schemas.user import UserOut

router = APIRouter(prefix="/me", tags=["me"])

@router.get("/get_me", response_model=UserOut, dependencies=[Depends(require_perm("self:read"))])
def me(user: Users = Depends(get_current_user)):
    # user đã được load kèm role ở get_current_user
    return UserOut(
        user_id=user.user_id,
        username=user.username,
        phone=user.phone,
        email=user.email,
        avt_url=user.avt_url,
        address=user.address,
        status=user.status.value if hasattr(user.status, "value") else user.status,
        role_type=(user.role.role_type.value if user.role else None),
    )

@router.put("/update_me", response_model=UserOut, dependencies=[Depends(require_perm("self:update"))])
def update_me(
    username: str | None = Form(None),
    phone: str | None = Form(None),
    email: str | None = Form(None),
    address: str | None = Form(None),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    # chỉ sửa trường cơ bản của chính mình (không động vào role_id)
    if username and username != user.username:
        from sqlalchemy import select
        if db.scalar(select(Users).where(Users.username == username)):
            raise HTTPException(status_code=409, detail="Username đã tồn tại")
        user.username = username

    if phone and phone != user.phone:
        if db.scalar(select(Users).where(Users.phone == phone)):
            raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")
        user.phone = phone

    if email is not None and email != user.email:
        if email and db.scalar(select(Users).where(Users.email == email)):
            raise HTTPException(status_code=409, detail="Email đã tồn tại")
        user.email = email

    if address is not None:
        user.address = address

    db.commit(); db.refresh(user)
    return user
