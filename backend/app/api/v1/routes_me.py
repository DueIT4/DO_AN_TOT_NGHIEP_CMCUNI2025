# from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
# from sqlalchemy.orm import Session
# from sqlalchemy import select
# from pathlib import Path
# from uuid import uuid4
# import shutil

# from app.core.database import get_db
# from app.api.v1.deps import get_current_user
# from app.services.permissions import require_perm
# from app.models.user import Users
# from app.schemas.user import UserOut

# router = APIRouter(prefix="/me", tags=["me"])

# @router.get("/get_me", response_model=UserOut, dependencies=[Depends(require_perm("self:read"))])
# def me(user: Users = Depends(get_current_user)):
#     # user đã được load kèm role ở get_current_user
#     return UserOut(
#         user_id=user.user_id,
#         username=user.username,
#         phone=user.phone,
#         email=user.email,
#         avt_url=user.avt_url,
#         address=user.address,
#         status=user.status.value if hasattr(user.status, "value") else user.status,
#         role_type=(user.role.role_type.value if user.role else None),
#     )

# @router.put("/update_me", response_model=UserOut, dependencies=[Depends(require_perm("self:update"))])
# def update_me(
#     username: str | None = Form(None),
#     phone: str | None = Form(None),
#     email: str | None = Form(None),
#     address: str | None = Form(None),
#     db: Session = Depends(get_db),
#     user: Users = Depends(get_current_user),
# ):
#     # chỉ sửa trường cơ bản của chính mình (không động vào role_id)
#     if username and username != user.username:
#         from sqlalchemy import select
#         if db.scalar(select(Users).where(Users.username == username)):
#             raise HTTPException(status_code=409, detail="Username đã tồn tại")
#         user.username = username

#     if phone and phone != user.phone:
#         if db.scalar(select(Users).where(Users.phone == phone)):
#             raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")
#         user.phone = phone

#     if email is not None and email != user.email:
#         if email and db.scalar(select(Users).where(Users.email == email)):
#             raise HTTPException(status_code=409, detail="Email đã tồn tại")
#         user.email = email

#     if address is not None:
#         user.address = address

#     db.commit(); db.refresh(user)
#     return user

# # routes_me2
# @router.post("/avatar", response_model=UserOut, dependencies=[Depends(require_perm("self:update"))])
# def upload_avatar2(
#     file: UploadFile = File(...),
#     db: Session = Depends(get_db),
#     user: Users = Depends(get_current_user),
# ):
#     if not file.content_type or not file.content_type.startswith("image/"):
#         raise HTTPException(status_code=400, detail="Chỉ nhận file ảnh")

#     ext = Path(file.filename or "").suffix.lower() or ".png"
#     if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
#         raise HTTPException(status_code=400, detail="Định dạng ảnh không hỗ trợ")

#     if user.avt_url:
#         old_path = Path(user.avt_url.lstrip("/"))
#         try:
#             if old_path.is_file():
#                 old_path.unlink()
#         except Exception:
#             pass

#     save_dir = Path("media/avatars")
#     save_dir.mkdir(parents=True, exist_ok=True)
#     fname = f"user_{user.user_id}_{uuid4().hex}{ext}"
#     save_path = save_dir / fname
#     with save_path.open("wb") as f:
#         shutil.copyfileobj(file.file, f)

#     user.avt_url = f"/media/avatars/{fname}"
#     db.add(user); db.commit(); db.refresh(user)
#     return user

from fastapi import APIRouter, Depends, HTTPException, status, Form, UploadFile, File
from sqlalchemy.orm import Session
from sqlalchemy import select
from pathlib import Path
from uuid import uuid4
import shutil

from app.core.database import get_db
from app.api.v1.deps import get_current_user
from app.services.permissions import require_perm
from app.models.user import Users
from app.schemas.user import UserOut

router = APIRouter(prefix="/me", tags=["me"])

# ====== HELPER DÙNG CHUNG (XÓA & LƯU AVATAR) ======

def _delete_avatar_if_exists(avt_url: str | None) -> None:
    """Xoá file avatar cũ nếu tồn tại (đường dẫn tương đối)."""
    if not avt_url:
        return
    old_path = Path(avt_url.lstrip("/"))
    try:
        if old_path.is_file():
            old_path.unlink()
    except Exception:
        # không cần raise lỗi, tránh làm hỏng luồng chính
        pass

def _save_avatar_file(file: UploadFile, prefix: str) -> str:
    """
    Lưu file ảnh avatar giống logic ở /users/update:
    - Chỉ nhận image/*
    - Chỉ cho phép .jpg, .jpeg, .png, .webp
    - Lưu vào media/avatars
    - Trả về đường dẫn tương đối, ví dụ: /media/avatars/1234_xxx.png
    """
    if not (file.content_type or "").startswith("image/"):
        raise HTTPException(status_code=400, detail="Chỉ nhận file ảnh")

    ext = (Path(file.filename or "").suffix or ".png").lower()
    if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
        raise HTTPException(status_code=400, detail="Định dạng ảnh không hỗ trợ")

    fname = f"{prefix}_{uuid4().hex}{ext}"
    save_path = (Path("media") / "avatars") / fname
    save_path.parent.mkdir(parents=True, exist_ok=True)

    with save_path.open("wb") as f:
        shutil.copyfileobj(file.file, f)

    return f"/media/avatars/{fname}"

# ====== GET ME ======

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

# ====== UPDATE ME (thông tin cơ bản, không avatar) ======

@router.put("/update_me", response_model=UserOut,
            dependencies=[Depends(require_perm("self:update"))])
def update_me(
    # tất cả trường đều tùy chọn: FE chỉ gửi cái cần đổi
    username: str | None = Form(None),
    phone: str | None = Form(None),
    email: str | None = Form(None),
    address: str | None = Form(None),
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    """
    Cập nhật thông tin CƠ BẢN của chính mình:
    - username
    - phone
    - email
    - address

    KHÔNG cho đổi:
    - password
    - role_id

    Permission: self:update
    """

    # --- VALIDATE & CHỐNG TRÙNG NẾU CÓ GỬI LÊN ---

    # Username
    if username and username != user.username:
        if db.scalar(select(Users).where(Users.username == username)):
            raise HTTPException(status_code=409, detail="Username đã tồn tại")
        user.username = username

    # Phone
    if phone and phone != user.phone:
        p = phone.strip()
        if not p.isdigit():
            raise HTTPException(status_code=400, detail="Số điện thoại chỉ gồm chữ số")
        if db.scalar(select(Users).where(Users.phone == p)):
            raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")
        user.phone = p

    # Email: cho phép để trống (NULL)
    if email is not None:
        email = email.strip()

        # Nếu người dùng xoá hết -> NULL
        if email == "":
            user.email = None
        else:
            # Check trùng email nếu có nhập giá trị
            exists = db.scalar(
                select(Users).where(
                    Users.email == email,
                    Users.user_id != user.user_id   # Không so với chính mình
                )
            )
            if exists:
                raise HTTPException(status_code=409, detail="Email đã tồn tại")

            user.email = email


    # Address
    if address is not None:
        user.address = address

    db.commit()
    db.refresh(user)
    return user


# ====== UPLOAD AVATAR (GIỐNG LOGIC /users/update) ======

@router.post("/avatar", response_model=UserOut, dependencies=[Depends(require_perm("self:update"))])
def upload_avatar2(
    file: UploadFile = File(...),  # vẫn bắt buộc phải gửi file
    db: Session = Depends(get_db),
    user: Users = Depends(get_current_user),
):
    # Xoá avatar cũ nếu có (giống /users/update)
    _delete_avatar_if_exists(user.avt_url)

    # Lưu avatar mới (giống /users/update, chỉ khác prefix dùng user.user_id)
    avt_url = _save_avatar_file(file, prefix=str(user.user_id))

    # Cập nhật user
    user.avt_url = avt_url
    db.add(user)
    db.commit()
    db.refresh(user)
    return user
