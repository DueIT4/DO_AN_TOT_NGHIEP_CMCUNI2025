from fastapi import APIRouter, Depends, HTTPException, status, Form, File, UploadFile
from sqlalchemy.orm import Session
from sqlalchemy import select
from pathlib import Path
from datetime import datetime
from typing import Optional

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.services.permissions import require_perm
from app.models.user import Users
from app.schemas.user import UserOut
from app.services.passwords import hash_password, verify_password
from app.schemas.user import ChangePasswordIn
from app.services.cloudinary_service import upload_image_to_cloudinary  # ✅ Thêm service Cloudinary

router = APIRouter(prefix="/me", tags=["me"])


@router.put(
    "/change_password",
    status_code=status.HTTP_200_OK,
    dependencies=[Depends(require_perm("self:update"))],
)
def change_password(
    payload: ChangePasswordIn,
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    # user.password là bcrypt hash
    if not user.password:
        raise HTTPException(status_code=400, detail="Tài khoản chưa có mật khẩu")

    if not verify_password(payload.old_password, user.password):
        raise HTTPException(status_code=400, detail="Mật khẩu hiện tại không đúng")

    # Không cho đặt mật khẩu mới giống cũ (tuỳ bạn)
    if verify_password(payload.new_password, user.password):
        raise HTTPException(status_code=400, detail="Mật khẩu mới phải khác mật khẩu cũ")

    user.password = hash_password(payload.new_password)
    db.commit()
    return {"ok": True, "message": "Đổi mật khẩu thành công"}

@router.get("/get_me", response_model=UserOut, dependencies=[Depends(require_perm("self:read"))])
def me(user: Users = Depends(get_current_user)):
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

    db.commit()
    db.refresh(user)
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


# 🔥 API RIÊNG: cập nhật avatar lên Cloudinary
@router.post(
    "/update_avatar",
    response_model=UserOut,
    dependencies=[Depends(require_perm("self:update"))]
)
async def update_avatar(
    avatar: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    # 1. Đọc file
    content = await avatar.read()
    if not content:
        raise HTTPException(status_code=400, detail="File avatar trống")

    # 2. Tải lên Cloudinary thay vì lưu vào Disk
    # Folder được đặt là 'zestguard/avatars' để quản lý riêng với ảnh detection
    image_url = upload_image_to_cloudinary(content, folder="zestguard/avatars")
    
    if not image_url:
        raise HTTPException(status_code=500, detail="Lỗi khi tải ảnh đại diện lên Cloudinary")

    # 3. Cập nhật URL mới vào database (Lưu link https://res.cloudinary.com/...)
    user.avt_url = image_url

    db.commit()
    db.refresh(user)

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