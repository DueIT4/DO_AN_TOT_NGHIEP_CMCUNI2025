<<<<<<< HEAD
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, update, and_
from app.core.database import get_db
from app.schemas.auth import RegisterPhoneIn, RegisterGoogleIn, RegisterFacebookIn, RegisterOut
from app.models.user import Users, UserStatus
from app.models.auth_account import AuthAccount, Provider
from app.services.confirm_token import make_confirm_token, parse_confirm_token
from app.services.notifier import send_sms, send_email, send_facebook_dm
from app.schemas.auth import LoginPhoneIn, SocialLoginIn, TokenOut
from app.services.auth_jwt import make_access_token
from app.models.role import Role, RoleType
from app.services.identity_verify import (
    phone_exists_really, verify_google_id_token, verify_facebook_access_token
)
import hashlib

def _hash_password_sha256(raw: str) -> str:
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

def get_default_viewer_role_id(db: Session) -> int:
    role = db.scalar(select(Role).where(Role.role_type == RoleType.viewer))
    if not role:
        raise HTTPException(status_code=500, detail="Thiếu role mặc định 'viewer' trong bảng role")
    return role.role_id

router = APIRouter(prefix="/auth", tags=["auth"])

# ===== 1) Đăng ký bằng SĐT =====
@router.post("/register/phone", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_phone(payload: RegisterPhoneIn, db: Session = Depends(get_db)):
    # A. KIỂM TRA "CÓ THỰC"
    if not phone_exists_really(payload.phone):
        # bạn thay hàm phone_exists_really bằng HLR/OTP thực để chuẩn xác
        raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")

    # B. KIỂM TRA "CHƯA TỪNG ĐĂNG KÝ"
    if db.scalar(select(Users).where(Users.phone == payload.phone)):
        raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")
    if db.scalar(select(Users).where(Users.username == payload.username)):
        raise HTTPException(status_code=409, detail="Username đã tồn tại")
    viewer_role_id = get_default_viewer_role_id(db)
    # C. TẠO USER + AUTH_ACCOUNT (chưa verified)
    user = Users(
        username=payload.username,
        phone=payload.phone,
        password=_hash_password_sha256(payload.password),
        status=UserStatus.active,
        role_id=viewer_role_id,
    )
    db.add(user)
    db.flush()

    acc = AuthAccount(
        user_id=user.user_id,
        provider=Provider.sdt,           # 'sđt'
        provider_user_id=payload.phone,  # số điện thoại
        phone_verified=True
    )
    db.add(acc)
    db.commit()

    # D. GỬI THÔNG BÁO XÁC NHẬN QUA SĐT (link bấm OK)
    token = make_confirm_token(user.user_id, "sđt", payload.phone, minutes=30)
    confirm_url = f"/api/v1/auth/confirm?token={token}"
    send_sms(payload.phone, f"Xac nhan so dien thoai: {confirm_url}")

    return RegisterOut(
        user_id=user.user_id,
        username=user.username,
        phone=user.phone,
        provider="sdt",
        message="Đã gửi xác nhận về số điện thoại."
    )

# ===== 2) Đăng ký bằng GOOGLE (yêu cầu id_token hợp lệ) =====
@router.post("/register/google", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_google(payload: RegisterGoogleIn, db: Session = Depends(get_db)):
    # A. KIỂM TRA "CÓ THỰC"
    verified = verify_google_id_token(payload.id_token)
    if not verified:
        raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")
    google_sub, google_email = verified  # google_sub là ID duy nhất từ Google

    # B. KIỂM TRA "CHƯA TỪNG ĐĂNG KÝ"
    if db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.gg,
        AuthAccount.provider_user_id == google_sub
    )):
        raise HTTPException(status_code=409, detail="Gmail/Google đã tồn tại")
    # (tuỳ chọn) nếu bạn muốn chặn trùng email ở bảng users:
    if google_email and db.scalar(select(Users).where(Users.email == google_email)):
        raise HTTPException(status_code=409, detail="Gmail đã tồn tại")
    viewer_role_id = get_default_viewer_role_id(db)
    # C. TẠO USER + AUTH_ACCOUNT
    user = Users(
        username=payload.username,
        email=google_email,
        status=UserStatus.active,
        role_id=viewer_role_id,
    )
    db.add(user)
    db.flush()

    acc = AuthAccount(
        user_id=user.user_id,
        provider=Provider.gg,
        provider_user_id=google_sub,
        phone_verified=False  # cờ này chỉ áp cho SĐT; giữ False/không dùng cho gg
    )
    db.add(acc)
    db.commit()

    # D. GỬI EMAIL XÁC NHẬN (nếu có email)
    if google_email:
        token = make_confirm_token(user.user_id, "email", google_email, minutes=30)
        confirm_url = f"/api/v1/auth/confirm?token={token}"
        send_email(google_email, "Xác nhận đăng ký", f"Bạn đã đăng ký. Bấm link để xác nhận: {confirm_url}")

    return RegisterOut(
        user_id=user.user_id,
        username=user.username,
        provider="gg",
        message="Đã gửi xác nhận qua Gmail (nếu có)."
    )

# ===== 3) Đăng ký bằng FACEBOOK (yêu cầu access_token hợp lệ) =====
@router.post("/register/facebook", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_facebook(payload: RegisterFacebookIn, db: Session = Depends(get_db)):
    # A. KIỂM TRA "CÓ THỰC"
    fb_uid = verify_facebook_access_token(payload.access_token)
    if not fb_uid:
        raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")

    # B. KIỂM TRA "CHƯA TỪNG ĐĂNG KÝ"
    if db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.fb,
        AuthAccount.provider_user_id == fb_uid
    )):
        raise HTTPException(status_code=409, detail="Facebook đã tồn tại")

    # C. TẠO USER + AUTH_ACCOUNT
    viewer_role_id = get_default_viewer_role_id(db)
    user = Users(
        username=payload.username,
        status=UserStatus.active,
        role_id=viewer_role_id,
    )
    db.add(user)
    db.flush()

    acc = AuthAccount(
        user_id=user.user_id,
        provider=Provider.fb,
        provider_user_id=fb_uid,
        phone_verified=False
    )
    db.add(acc)
    db.commit()

    # D. GỬI XÁC NHẬN QUA FB (DM) (stub)
    token = make_confirm_token(user.user_id, "fb", fb_uid, minutes=30)
    confirm_url = f"/api/v1/auth/confirm?token={token}"
    send_facebook_dm(fb_uid, f"Ban da dang ky. Xac nhan tai khoan: {confirm_url}")

    return RegisterOut(
        user_id=user.user_id,
        username=user.username,
        provider="fb",
        message="Đã gửi xác nhận qua Facebook DM."
    )

# ===== 4) Endpoint người dùng bấm OK xác nhận =====
@router.get("/confirm", status_code=200)
def confirm(token: str = Query(...), db: Session = Depends(get_db)):
    try:
        data = parse_confirm_token(token)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Token không hợp lệ: {e}")

    uid = int(data["uid"])
    channel = data["ch"]
    value = data["val"]

    if channel == "sdt":
        acc = db.scalar(select(AuthAccount).where(
            AuthAccount.user_id == uid,
            AuthAccount.provider == Provider.sdt,
            AuthAccount.provider_user_id == value
        ))
        if not acc:
            raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản SĐT để xác nhận")
        if not acc.phone_verified:
            db.execute(
                update(AuthAccount)
                .where(and_(
                    AuthAccount.user_id == uid,
                    AuthAccount.provider == Provider.sdt,
                    AuthAccount.provider_user_id == value
                ))
                .values(phone_verified=True)
            )
            db.commit()
        return {"ok": True, "message": "Đã xác nhận số điện thoại"}

    # Email / FB: hiện không có cờ verified trong DB; xác nhận logic
    return {"ok": True, "message": f"Đã xác nhận kênh {channel}"}

# --- Helper hash (dùng cùng thuật toán với đăng ký) ---
def _hash_password_sha256(raw: str) -> str:
    import hashlib
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()

# ======================
#  ĐĂNG NHẬP BẰNG SĐT
# ======================
@router.post("/login/phone", response_model=TokenOut)
def login_phone(payload: LoginPhoneIn, db: Session = Depends(get_db)):
    user = db.scalar(select(Users).where(Users.phone == payload.phone))
    if not user:
        # Số chưa hề đăng ký
        raise HTTPException(status_code=404, detail="Số điện thoại chưa đăng ký")

    # Kiểm mật khẩu
    if user.password != _hash_password_sha256(payload.password):
        raise HTTPException(status_code=401, detail="Mật khẩu không đúng")

    # (khuyến nghị) bắt buộc xác nhận sđt trước khi cho login
    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.user_id == user.user_id,
        AuthAccount.provider == Provider.sdt
    ))
    if acc and not acc.phone_verified:
        raise HTTPException(status_code=403, detail="Số điện thoại chưa xác nhận")

    token = make_access_token(user.user_id)
    return TokenOut(access_token=token, user_id=user.user_id, username=user.username)

# ======================
#  ĐĂNG NHẬP GOOGLE
# ======================
@router.post("/login/google", response_model=TokenOut)
def login_google(payload: SocialLoginIn, db: Session = Depends(get_db)):
    verified = verify_google_id_token(payload.token)
    if not verified:
        # token không hợp lệ -> không phải “tiếp tục với Google” hợp lệ
        raise HTTPException(status_code=400, detail="Token Google không hợp lệ")
    google_sub, _email = verified

    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.gg,
        AuthAccount.provider_user_id == google_sub
    ))
    if not acc:
        # người dùng chưa đăng ký trước đó
        raise HTTPException(status_code=404, detail="Tài khoản Google chưa đăng ký")

    user = db.get(Users, acc.user_id)
    token = make_access_token(user.user_id)
    return TokenOut(access_token=token, user_id=user.user_id, username=user.username)

# ======================
#  ĐĂNG NHẬP FACEBOOK
# ======================
@router.post("/login/facebook", response_model=TokenOut)
def login_facebook(payload: SocialLoginIn, db: Session = Depends(get_db)):
    fb_uid = verify_facebook_access_token(payload.token)
    if not fb_uid:
        raise HTTPException(status_code=400, detail="Token Facebook không hợp lệ")

    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.fb,
        AuthAccount.provider_user_id == fb_uid
    ))
    if not acc:
        raise HTTPException(status_code=404, detail="Tài khoản Facebook chưa đăng ký")

    user = db.get(Users, acc.user_id)
    token = make_access_token(user.user_id)
    return TokenOut(access_token=token, user_id=user.user_id, username=user.username)
=======
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.firebase_admin import init_firebase
from app.services.auth_service import login_with_firebase_idtoken

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/firebase")
def login_with_firebase(id_token: str, db: Session = Depends(get_db)):
    try:
        init_firebase()
        return login_with_firebase_idtoken(db, id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
>>>>>>> 11d9fd14ef0953ddc8cc89054bcd533fde9e4f7c
