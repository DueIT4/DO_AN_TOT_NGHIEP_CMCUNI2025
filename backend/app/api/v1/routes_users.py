# from sqlalchemy.orm import Session
# from sqlalchemy import select
# from app.core.database import get_db
# from app.schemas.user import UserCreate, UserOut
# from app.models.user import Users, UserStatus
# from fastapi import APIRouter, Depends, UploadFile, File, HTTPException, status, Request, Form
# from sqlalchemy.orm import Session
# from pathlib import Path
# from uuid import uuid4

# from app.core.database import get_db
# from app.models.user import Users
# from app.schemas.user import UserOut
# import hashlib, shutil

# router = APIRouter(prefix="/users", tags=["users"])

# def _hash_password_sha256(raw: str) -> str:
#     return hashlib.sha256(raw.encode("utf-8")).hexdigest()

# @router.post("", response_model=UserOut, status_code=status.HTTP_201_CREATED)
# def create_user(payload: UserCreate, db: Session = Depends(get_db)):
#     # 1) Chống trùng dữ liệu bắt buộc/unique
#     if db.scalar(select(Users).where(Users.username == payload.username)):
#         raise HTTPException(status_code=409, detail="Username đã tồn tại")

#     if db.scalar(select(Users).where(Users.phone == payload.phone)):
#         raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")

#     if payload.email and db.scalar(select(Users).where(Users.email == payload.email)):
#         raise HTTPException(status_code=409, detail="Email đã tồn tại")

#     # 2) Tạo bản ghi Users
#     user = Users(
#         username=payload.username,
#         phone=payload.phone,
#         password=_hash_password_sha256(payload.password),
#         # các trường có thể null
#         email=payload.email,
#         avt_url=payload.avt_url,
#         address=payload.address,
#         # trạng thái mặc định
#         status=UserStatus.active,  # created_at sẽ tự set theo DB
#     )
#     db.add(user)
#     db.commit()      # flush + commit để lấy id và ghi DB
#     db.refresh(user) # sync lại object

#     return user

# router = APIRouter(prefix="/users", tags=["users"])

# @router.put("/{user_id}/avatar", response_model=UserOut)
# def upload_avatar(user_id: int, file: UploadFile = File(...), db: Session = Depends(get_db)):
#     user = db.get(Users, user_id)
#     if not user:
#         raise HTTPException(404, "Không tìm thấy user")

#     # Chỉ nhận ảnh
#     if not file.content_type.startswith("image/"):
#         raise HTTPException(400, "Chỉ nhận file ảnh")

#     # Lưu file vào media/avatars
#     ext = Path(file.filename).suffix.lower()
#     if ext not in [".jpg", ".jpeg", ".png", ".webp"]:
#         raise HTTPException(400, "Định dạng ảnh không hỗ trợ")

#     fname = f"{user_id}_{uuid4().hex}{ext}"
#     save_path = Path("media/avatars") / fname
#     with save_path.open("wb") as f:
#         f.write(file.file.read())

#     # Xoá avatar cũ nếu có (không bắt buộc)
#     if user.avt_url:
#         old = Path("." + user.avt_url) if user.avt_url.startswith("/") else Path(user.avt_url)
#         try:
#             if old.is_file():
#                 old.unlink()
#         except Exception:
#             pass

#     # Lưu đường dẫn TƯƠNG ĐỐI vào DB (ví dụ: /media/avatars/xxx.png)
#     user.avt_url = f"/media/avatars/{fname}"
#     db.commit()
#     db.refresh(user)
#     return user
# app/api/v1/routes_users.py
from fastapi import APIRouter, Depends, HTTPException, status, UploadFile, File, Form
from sqlalchemy.orm import Session
from sqlalchemy import select
from app.core.database import get_db
from app.models.user import Users, UserStatus
from app.schemas.user import UserOut, UserListOut
from app.models.role import Role, RoleType
from uuid import uuid4
from pathlib import Path
from sqlalchemy import select, func, or_ 
from typing import List
from sqlalchemy.orm import joinedload
from app.services.permissions import require_roles, require_perm
import hashlib, shutil

router = APIRouter(prefix="/users", tags=["users"])

def _hash_password_sha256(s: str) -> str:
    import hashlib; return hashlib.sha256(s.encode("utf-8")).hexdigest()

def _to_user_out(u: Users) -> UserOut:
    rt = getattr(u.role, "role_type", None)
    role_type = getattr(rt, "value", rt)   # Enum -> string
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
    """Lấy role_id của viewer. Nếu chưa có, báo lỗi để seed data."""
    role = db.scalar(select(Role).where(Role.role_type == RoleType.viewer))
    if not role:
        # fallback theo name nếu bạn seed theo name
        role = db.scalar(select(Role).where(Role.name == "viewer"))
    if not role:
        raise HTTPException(500, "Chưa có role mặc định 'viewer' trong bảng role. Vui lòng seed dữ liệu role.")
    return role.role_id

def _ensure_role_exists(db: Session, role_id: int) -> None:
    if not db.get(Role, role_id):
        raise HTTPException(400, "role_id không tồn tại")

# Tạo user: admin & support_admin
@router.post("/create", response_model=UserOut, status_code=status.HTTP_201_CREATED,
             dependencies=[Depends(require_perm("users:create"))])
def create_user(
    # Các field text sẽ đi theo multipart khi kèm file
    username: str = Form(...),
    phone: str = Form(...),
    password: str = Form(...),
    email: str | None = Form(None),
    address: str | None = Form(None),
    role_id: int | None = Form(None),
    file: UploadFile | None = File(None),  # ảnh avatar (tùy chọn)
    db: Session = Depends(get_db),
):
    # chống trùng
    if db.scalar(select(Users).where(Users.username == username)):
        raise HTTPException(409, "Username đã tồn tại")
    if db.scalar(select(Users).where(Users.phone == phone)):
        raise HTTPException(409, "Số điện thoại đã tồn tại")
    if email and db.scalar(select(Users).where(Users.email == email)):
        raise HTTPException(409, "Email đã tồn tại")
    # xử lý ảnh nếu có
    avt_url = None
    if file:
        if not file.content_type.startswith("image/"):
            raise HTTPException(400, "Chỉ nhận file ảnh")
        Path("media/avatars").mkdir(parents=True, exist_ok=True)
        ext = Path(file.filename).suffix or ".png"
        fname = f"{uuid4().hex}{ext}"
        save_path = Path("media/avatars") / fname
        with save_path.open("wb") as f:
            shutil.copyfileobj(file.file, f)
        avt_url = f"/media/avatars/{fname}"   # <— chỉ lưu đường dẫn tương đối
    # chọn role_id
    if role_id is None:
        role_id = _get_default_viewer_role_id(db)
    else:
        _ensure_role_exists(db, role_id)
    user = Users(
        username=username,
        phone=phone,
        password=_hash_password_sha256(password),
        email=email,
        address=address,
        avt_url=avt_url,              # có thể None nếu không up ảnh
        status=UserStatus.active,
        role_id=role_id, 
    )
    db.add(user); db.commit(); db.refresh(user)
    return user
# === LẤY THÔNG TIN 1 USER (để đổ form) ===
# @router.get("/{user_id}", response_model=UserOut)
# def get_user(user_id: int, db: Session = Depends(get_db)):
#     user = db.get(Users, user_id)
#     if not user:
#         raise HTTPException(status_code=404, detail="Không tìm thấy user")
#     return user
@router.get("/get/{user_id}", response_model=UserOut,
    dependencies=[Depends(require_perm("users:list"))])
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.scalar(
        select(Users).options(joinedload(Users.role)).where(Users.user_id == user_id)
    )
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy user")
    return _to_user_out(user)

# === CẬP NHẬT THÔNG TIN USER (multipart, có thể thay avatar) ===
@router.put("/update/{user_id}", response_model=UserOut,
    dependencies=[Depends(require_perm("users:update"))])
def update_user(
    user_id: int,
    # tất cả trường đều tùy chọn: FE chỉ gửi cái cần đổi
    username: str | None = Form(None),
    phone: str | None = Form(None),
    password: str | None = Form(None),
    email: str | None = Form(None),
    address: str | None = Form(None),
    role_id: int | None = Form(None),
    file: UploadFile | None = File(None),   # avatar mới (tùy chọn)
    db: Session = Depends(get_db),
):
    user = db.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy user")

    # --- VALIDATE & CHỐNG TRÙNG NẾU CÓ GỬI LÊN ---
    if username and username != user.username:
        if db.scalar(select(Users).where(Users.username == username)):
            raise HTTPException(status_code=409, detail="Username đã tồn tại")
        user.username = username

    if phone and phone != user.phone:
        p = phone.strip()
        if not p.isdigit():
            raise HTTPException(status_code=400, detail="Số điện thoại chỉ gồm chữ số")
        if db.scalar(select(Users).where(Users.phone == p)):
            raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")
        user.phone = p

    if email is not None and email != user.email:
        # email có thể set None hoặc string; nếu string thì kiểm tra trùng
        if email and db.scalar(select(Users).where(Users.email == email)):
            raise HTTPException(status_code=409, detail="Email đã tồn tại")
        user.email = email

    if address is not None:
        user.address = address

    if password:
        user.password = _hash_password_sha256(password)
    
    if role_id is not None:
        _ensure_role_exists(db, role_id)
        user.role_id = role_id
    # --- ẢNH AVATAR (tùy chọn) ---
    if file:
        if not (file.content_type or "").startswith("image/"):
            raise HTTPException(status_code=400, detail="Chỉ nhận file ảnh")
        ext = Path(file.filename).suffix.lower() or ".png"
        if ext not in {".jpg", ".jpeg", ".png", ".webp"}:
            raise HTTPException(status_code=400, detail="Định dạng ảnh không hỗ trợ")

        # xóa ảnh cũ nếu có
        if user.avt_url:
            old_path = Path(user.avt_url.lstrip("/"))
            try:
                if old_path.is_file():
                    old_path.unlink()
            except Exception:
                pass

        # lưu ảnh mới
        fname = f"{user_id}_{uuid4().hex}{ext}"
        save_path = (Path("media") / "avatars") / fname
        save_path.parent.mkdir(parents=True, exist_ok=True)
        with save_path.open("wb") as f:
            shutil.copyfileobj(file.file, f)
        user.avt_url = f"/media/avatars/{fname}"

    db.commit()
    db.refresh(user)
    return user
from app.schemas.user import UserOut, UserListOut

@router.get("/search", response_model=UserListOut,
    dependencies=[Depends(require_perm("users:list"))])
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
            or_(Users.username.like(like), Users.phone.like(like), Users.email.like(like))
        )

    total = db.scalar(select(func.count()).select_from(stmt.subquery()))

    order_col = getattr(Users, order_by, Users.user_id)
    if order_dir.lower() == "desc":
        order_col = order_col.desc()
    else:
        order_col = order_col.asc()

    stmt = stmt.order_by(order_col).offset(max(page-1, 0) * size).limit(size)
    items = db.scalars(stmt.options(joinedload(Users.role))).all()

    return UserListOut(
        total=total or 0,
        items=[_to_user_out(u) for u in items]
    )

#### KHông nhập số trang hay từ khóa 
# @router.get("", response_model=List[UserOut])
# def list_users(db: Session = Depends(get_db)):
#     users = db.scalars(select(Users).order_by(Users.user_id.desc())).all()
#     return [_to_user_out(u) for u in users]
@router.get("", response_model=List[UserOut],
    dependencies=[Depends(require_perm("users:list"))])
def list_users(db: Session = Depends(get_db)):
    users = db.scalars(
        select(Users)
        .options(joinedload(Users.role))          # <<< load luôn role
        .order_by(Users.user_id.desc())
    ).all()
    return [_to_user_out(u) for u in users]
# === XÓA NGƯỜI DÙNG ===
@router.delete("/delete/{user_id}", status_code=status.HTTP_204_NO_CONTENT,
    dependencies=[Depends(require_perm("users:delete"))])
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.get(Users, user_id)
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy user")

    # không cho phép tự xóa chính mình (tùy chọn)
    # if current_user.user_id == user_id:
    #     raise HTTPException(status_code=400, detail="Không thể tự xóa chính mình")

    # xóa avatar nếu có
    if user.avt_url:
        path = Path(user.avt_url.lstrip("/"))
        try:
            if path.is_file():
                path.unlink()
        except Exception:
            pass

    db.delete(user)
    db.commit()
    return
