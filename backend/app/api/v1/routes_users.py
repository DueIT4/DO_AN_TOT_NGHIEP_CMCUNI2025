# app/api/v1/routes_users.py
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select, func, or_
from typing import List, Optional

from app.core.database import get_db
from app.models.user import Users, UserStatus
from app.schemas.user import UserOut, UserListOut
from app.models.role import Role, RoleType
from app.services.permissions import require_perm
from app.services.passwords import hash_password
from app.services.cloudinary_service import upload_image_to_cloudinary  # ✅ Thêm service Cloudinary

router = APIRouter(prefix="/users", tags=["users"])


def _to_user_out(u: Users) -> UserOut:
    rt = getattr(u.role, "role_type", None)
    role_type = getattr(rt, "value", rt)  # Enum -> string
    return UserOut(
        user_id=u.user_id,
        username=u.username,
        phone=u.phone,
        email=u.email,
        avt_url=u.avt_url,
        address=u.address,
        status=getattr(u.status, "value", u.status),
        role_type=role_type,
    )


def _get_default_viewer_role_id(db: Session) -> int:
    role = db.scalar(select(Role).where(Role.role_type == RoleType.viewer))
    if not role:
        raise HTTPException(
            500,
            "Chưa có role mặc định 'viewer' trong bảng role. Vui lòng seed dữ liệu role.",
        )
    return role.role_id


def _ensure_role_exists(db: Session, role_id: int) -> None:
    if not db.get(Role, role_id):
        raise HTTPException(400, "role_id không tồn tại")


# ========== TẠO USER (ADMIN / SUPPORT_ADMIN) ==========
@router.post(
    "/create",
    response_model=UserOut,
    status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_perm("users:create"))],
)
async def create_user(
    username: str = Form(...),
    phone: str = Form(...),
    password: str = Form(...),
    email: str | None = Form(None),
    address: str | None = Form(None),
    role_id: int | None = Form(None),
    status: str | None = Form(None),
    file: UploadFile | None = File(None),
    db: Session = Depends(get_db),
):
    # chống trùng
    if db.scalar(select(Users).where(Users.username == username)):
        raise HTTPException(409, "Username đã tồn tại")
    if db.scalar(select(Users).where(Users.phone == phone)):
        raise HTTPException(409, "Số điện thoại đã tồn tại")
    if email and db.scalar(select(Users).where(Users.email == email)):
        raise HTTPException(409, "Email đã tồn tại")

    # xử lý avatar qua Cloudinary
    avt_url = None
    if file:
        if not (file.content_type or "").startswith("image/"):
            raise HTTPException(400, "Chỉ nhận file ảnh")
        
        content = await file.read()
        avt_url = upload_image_to_cloudinary(content, folder="zestguard/avatars")
        if not avt_url:
            raise HTTPException(500, "Lỗi khi upload avatar lên Cloudinary")

    # role
    if role_id is None:
        role_id = _get_default_viewer_role_id(db)
    else:
        _ensure_role_exists(db, role_id)

    # status
    if status is None:
        user_status = UserStatus.active
    else:
        try:
            user_status = UserStatus(status)
        except ValueError:
            raise HTTPException(400, "Trạng thái không hợp lệ (active/inactive)")

    user = Users(
        username=username,
        phone=phone,
        password=hash_password(password),
        email=email,
        address=address,
        avt_url=avt_url,
        status=user_status,
        role_id=role_id,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


# ========== GET 1 USER ==========
@router.get(
    "/get/{user_id}",
    response_model=UserOut,
    dependencies=[Depends(require_perm("users:list"))],
)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.scalar(
        select(Users).options(joinedload(Users.role)).where(Users.user_id == user_id)
    )
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy user")
    return _to_user_out(user)


# ========== CẬP NHẬT USER ==========
@router.put(
    "/update/{user_id}",
    response_model=UserOut,
    dependencies=[Depends(require_perm("users:update"))],
)
async def update_user(
    user_id: int,
    username: str | None = Form(None),
    phone: str | None = Form(None),
    password: str | None = Form(None),
    email: str | None = Form(None),
    address: str | None = Form(None),
    role_id: int | None = Form(None),
    status: str | None = Form(None),
    file: UploadFile | None = File(None),
    db: Session = Depends(get_db),
):
    user = db.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy user")

    # username
    if username and username != user.username:
        if db.scalar(select(Users).where(Users.username == username)):
            raise HTTPException(status_code=409, detail="Username đã tồn tại")
        user.username = username

    # phone
    if phone and phone != user.phone:
        p = phone.strip()
        if not p.isdigit():
            raise HTTPException(400, "Số điện thoại chỉ gồm chữ số")
        if db.scalar(select(Users).where(Users.phone == p)):
            raise HTTPException(409, "Số điện thoại đã tồn tại")
        user.phone = p

    # email
    if email is not None and email != user.email:
        if email and db.scalar(select(Users).where(Users.email == email)):
            raise HTTPException(409, "Email đã tồn tại")
        user.email = email

    # address
    if address is not None:
        user.address = address

    # password
    if password:
        user.password = hash_password(password)

    # role
    if role_id is not None:
        _ensure_role_exists(db, role_id)
        user.role_id = role_id

    # status
    if status is not None:
        try:
            user.status = UserStatus(status)
        except ValueError:
            raise HTTPException(400, "Trạng thái không hợp lệ (active/inactive)")

    # avatar qua Cloudinary
    if file:
        if not (file.content_type or "").startswith("image/"):
            raise HTTPException(400, "Chỉ nhận file ảnh")
        
        content = await file.read()
        new_avt_url = upload_image_to_cloudinary(content, folder="zestguard/avatars")
        if not new_avt_url:
            raise HTTPException(500, "Lỗi khi upload avatar lên Cloudinary")
            
        # Lưu ý: Với Cloudinary, chúng ta không cần xoá file local. 
        # Nếu muốn xoá ảnh cũ trên Cloudinary, cần public_id, tạm thời chỉ cập nhật URL mới.
        user.avt_url = new_avt_url

    db.commit()
    db.refresh(user)
    return user


# ========== LIST + SEARCH ==========
@router.get(
    "/search",
    response_model=UserListOut,
    dependencies=[Depends(require_perm("users:list"))],
)
def list_users_search(
    q: str | None = None,
    page: int = 1,
    size: int = 20,
    order_by: str = "created_at",
    order_dir: str = "desc",
    db: Session = Depends(get_db),
):
    stmt = select(Users)
    if q:
        like = f"%{q}%"
        stmt = stmt.where(
            or_(
                Users.username.like(like),
                Users.phone.like(like),
                Users.email.like(like),
            )
        )

    total = db.scalar(select(func.count()).select_from(stmt.subquery()))

    order_col = getattr(Users, order_by, Users.user_id)
    if order_dir.lower() == "desc":
        order_col = order_col.desc()
    else:
        order_col = order_col.asc()

    stmt = stmt.order_by(order_col).offset(max(page - 1, 0) * size).limit(size)
    items = db.scalars(stmt.options(joinedload(Users.role))).all()

    return UserListOut(
        total=total or 0,
        items=[_to_user_out(u) for u in items],
    )


@router.get(
    "",
    response_model=List[UserOut],
    dependencies=[Depends(require_perm("users:list"))],
)
def list_users(db: Session = Depends(get_db)):
    users = db.scalars(
        select(Users)
        .options(joinedload(Users.role))
        .order_by(Users.user_id.desc())
    ).all()
    return [_to_user_out(u) for u in users]


# ========== "DELETE" = SOFT DELETE: SET INACTIVE ==========
@router.delete(
    "/delete/{user_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_perm("users:delete"))],
)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy user")

    # Không xoá cứng, chỉ set inactive
    user.status = UserStatus.inactive
    db.commit()
    return