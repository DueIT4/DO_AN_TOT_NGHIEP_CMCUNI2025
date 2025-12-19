import secrets
import httpx
from datetime import datetime, timedelta
from sqlalchemy import delete
from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, update, and_
from app.schemas.auth import TokenOut  # đã có
from app.services.auth_jwt import make_access_token
from app.core.database import get_db
from app.schemas.auth import (
    RegisterPhoneIn,
    RegisterGoogleIn,
    RegisterFacebookIn,
    RegisterOut,
    LoginPhoneIn,
    LoginIn,
    SocialLoginIn,
    TokenOut,
    ForgotPasswordIn,
    ForgotPasswordOTPIn,
    VerifyResetOTPIn,
    ResetPasswordIn,
    RegisterEmailIn
)
from app.models.user import Users, UserStatus
from app.models.auth_account import AuthAccount, Provider
from app.services.confirm_token import make_confirm_token, parse_confirm_token
from app.services.notifier import send_sms, send_email
from app.services.auth_jwt import make_access_token
from app.models.role import Role, RoleType
from app.models.password_reset import PasswordResetOTP
from app.models.password_reset import PasswordResetOTP
from app.services.otp_codes import hash_otp, verify_otp
from app.services.notifier import send_sms, send_email
from app.services.confirm_token import make_confirm_token
from app.services.identity_verify import (
    phone_exists_really, verify_google_id_token, verify_facebook_access_token
)

# ✅ bcrypt thuần (không passlib)
from app.services.passwords import hash_password, verify_password

router = APIRouter(prefix="/auth", tags=["auth"])


def get_default_viewer_role_id(db: Session) -> int:
    role = db.scalar(select(Role).where(Role.role_type == RoleType.viewer))
    if not role:
        raise HTTPException(status_code=500, detail="Thiếu role mặc định 'viewer' trong bảng role")
    return role.role_id


GOOGLE_USERINFO_URL = "https://openidconnect.googleapis.com/v1/userinfo"

def _looks_like_jwt(token: str) -> bool:
    # id_token thường có 3 phần ngăn bởi dấu .
    return token.count(".") == 2

def _looks_like_google_access_token(token: str) -> bool:
    # access_token của Google hay bắt đầu bằng ya29.
    return token.startswith("ya29.")

def get_google_userinfo_from_access_token(access_token: str) -> tuple[str, str | None]:
    """
    Return: (sub, email)
    """
    headers = {"Authorization": f"Bearer {access_token}"}
    r = httpx.get(GOOGLE_USERINFO_URL, headers=headers, timeout=10.0)

    if r.status_code != 200:
        raise HTTPException(status_code=400, detail=f"Token Google không hợp lệ (userinfo): {r.text}")

    data = r.json()
    sub = data.get("sub")
    email = data.get("email")

    if not sub:
        raise HTTPException(status_code=400, detail="Không lấy được 'sub' từ Google userinfo")

    return sub, email


# ===== 1) Đăng ký bằng SĐT =====
@router.post("/register/phone", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_phone(payload: RegisterPhoneIn, db: Session = Depends(get_db)):
    if not phone_exists_really(payload.phone):
        raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")

    if db.scalar(select(Users).where(Users.phone == payload.phone)):
        raise HTTPException(status_code=409, detail="Số điện thoại đã tồn tại")
    if db.scalar(select(Users).where(Users.username == payload.username)):
        raise HTTPException(status_code=409, detail="Username đã tồn tại")

    viewer_role_id = get_default_viewer_role_id(db)

    user = Users(
        username=payload.username,
        phone=payload.phone,
        password=hash_password(payload.password),  # ✅ bcrypt
        status=UserStatus.active,
        role_id=viewer_role_id,
    )
    db.add(user)
    db.flush()

    acc = AuthAccount(
        user_id=user.user_id,
        provider=Provider.sdt,
        provider_user_id=payload.phone,
        phone_verified=False,
    )
    db.add(acc)
    db.commit()

    token = make_confirm_token(user.user_id, "sdt", payload.phone, minutes=30)
    confirm_url = f"/api/v1/auth/confirm?token={token}"
    send_sms(payload.phone, f"Xac nhan so dien thoai: {confirm_url}")

    return RegisterOut(
        user_id=user.user_id,
        username=user.username,
        phone=user.phone,
        provider="sdt",
        message="Đã gửi xác nhận về số điện thoại."
    )


@router.post("/register/email", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_email(payload: RegisterEmailIn, db: Session = Depends(get_db)):
    email = payload.email.strip().lower()

    if db.scalar(select(Users).where(Users.email == email)):
        raise HTTPException(status_code=409, detail="Email đã tồn tại")
    if db.scalar(select(Users).where(Users.username == payload.username)):
        raise HTTPException(status_code=409, detail="Username đã tồn tại")

    viewer_role_id = get_default_viewer_role_id(db)

    user = Users(
        username=payload.username,
        email=email,
        password=hash_password(payload.password),
        status=UserStatus.active,
        role_id=viewer_role_id,
    )
    db.add(user)
    db.flush()

    acc = AuthAccount(
        user_id=user.user_id,
        provider=Provider.email,
        provider_user_id=email,
        phone_verified=False,  # tạm dùng như "verified"
    )
    db.add(acc)
    db.commit()

    token_confirm = make_confirm_token(user.user_id, "email", email, minutes=30)

    API_URL = "http://127.0.0.1:8000"
    confirm_url = f"{API_URL}/api/v1/auth/confirm?token={token_confirm}"
    send_email(email, "Xác nhận đăng ký", f"Bấm để xác nhận: {confirm_url}")

    return RegisterOut(
        user_id=user.user_id,
        username=user.username,
        phone=None,
        provider="email",
        message="Đã gửi email xác nhận. Vui lòng xác nhận trước khi đăng nhập."
    )


# ===== 2) Đăng ký bằng GOOGLE =====
@router.post("/register/google", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_google(payload: RegisterGoogleIn, db: Session = Depends(get_db)):
    verified = verify_google_id_token(payload.id_token)
    if not verified:
        raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")
    google_sub, google_email = verified

    if db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.gg,
        AuthAccount.provider_user_id == google_sub
    )):
        raise HTTPException(status_code=409, detail="Gmail/Google đã tồn tại")

    if google_email and db.scalar(select(Users).where(Users.email == google_email)):
        raise HTTPException(status_code=409, detail="Gmail đã tồn tại")

    viewer_role_id = get_default_viewer_role_id(db)

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
        phone_verified=False
    )
    db.add(acc)
    db.commit()

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


# # ===== 3) Đăng ký bằng FACEBOOK =====
# @router.post("/register/facebook", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
# def register_facebook(payload: RegisterFacebookIn, db: Session = Depends(get_db)):
#     fb_uid = verify_facebook_access_token(payload.access_token)
#     if not fb_uid:
#         raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")

#     if db.scalar(select(AuthAccount).where(
#         AuthAccount.provider == Provider.fb,
#         AuthAccount.provider_user_id == fb_uid
#     )):
#         raise HTTPException(status_code=409, detail="Facebook đã tồn tại")

#     viewer_role_id = get_default_viewer_role_id(db)

#     user = Users(
#         username=payload.username,
#         status=UserStatus.active,
#         role_id=viewer_role_id,
#     )
#     db.add(user)
#     db.flush()

#     acc = AuthAccount(
#         user_id=user.user_id,
#         provider=Provider.fb,
#         provider_user_id=fb_uid,
#         phone_verified=False
#     )
#     db.add(acc)
#     db.commit()

#     token = make_confirm_token(user.user_id, "fb", fb_uid, minutes=30)
#     confirm_url = f"/api/v1/auth/confirm?token={token}"
#     send_facebook_dm(fb_uid, f"Ban da dang ky. Xac nhan tai khoan: {confirm_url}")

#     return RegisterOut(
#         user_id=user.user_id,
#         username=user.username,
#         provider="fb",
#         message="Đã gửi xác nhận qua Facebook DM."
#     )


# ===== 4) Endpoint xác nhận =====
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
    if channel == "email":
        acc = db.scalar(select(AuthAccount).where(
            AuthAccount.user_id == uid,
            AuthAccount.provider == Provider.email,
            AuthAccount.provider_user_id == value
        ))
        if not acc:
            raise HTTPException(404, "Không tìm thấy tài khoản email để xác nhận")

        if not acc.phone_verified:
            db.execute(
                update(AuthAccount)
                .where(and_(
                    AuthAccount.user_id == uid,
                    AuthAccount.provider == Provider.email,
                    AuthAccount.provider_user_id == value
                ))
                .values(phone_verified=True)
            )
            db.commit()


    return {"ok": True, "message": f"Đã xác nhận kênh {channel}"}



# ======================
#  ĐĂNG NHẬP (EMAIL / PHONE)
# ======================
@router.post("/login", response_model=TokenOut)
def login(payload: LoginIn, db: Session = Depends(get_db)):
    user = None
    if payload.email:
        user = db.scalar(select(Users).where(Users.email == payload.email))
    elif payload.phone:
        user = db.scalar(select(Users).where(Users.phone == payload.phone))

    if not user:
        raise HTTPException(status_code=404, detail="Email/số điện thoại chưa đăng ký")

    if not verify_password(payload.password, user.password):  # ✅ bcrypt verify
        raise HTTPException(status_code=401, detail="Mật khẩu không đúng")

    if user.status != UserStatus.active:
        raise HTTPException(status_code=403, detail="Tài khoản đã bị khóa")

    token = make_access_token(user.user_id)
    return TokenOut(access_token=token, user_id=user.user_id, username=user.username)


# ======================
#  ĐĂNG NHẬP BẰNG SĐT
# ======================
@router.post("/login/phone", response_model=TokenOut)
def login_phone(payload: LoginPhoneIn, db: Session = Depends(get_db)):
    user = db.scalar(select(Users).where(Users.phone == payload.phone))
    if not user:
        raise HTTPException(status_code=404, detail="Số điện thoại chưa đăng ký")

    if not verify_password(payload.password, user.password):  # ✅ bcrypt verify
        raise HTTPException(status_code=401, detail="Mật khẩu không đúng")

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
    tok = payload.token.strip()

    # 1) Nếu là id_token (Android thường có)
    if _looks_like_jwt(tok):
        verified = verify_google_id_token(tok)
        if not verified:
            raise HTTPException(status_code=400, detail="Token Google không hợp lệ (id_token)")
        google_sub, google_email = verified

    # 2) Nếu là access_token (Web của bạn đang gặp)
    elif _looks_like_google_access_token(tok):
        google_sub, google_email = get_google_userinfo_from_access_token(tok)

    else:
        raise HTTPException(status_code=400, detail="Token Google không đúng định dạng")

    # Tìm auth account theo google_sub
    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.gg,
        AuthAccount.provider_user_id == google_sub
    ))

    # Nếu CHƯA đăng ký trước đó -> bạn có 2 lựa chọn:
    # A) 404 như cũ
    # B) Tự động tạo user luôn (giống social login)
    # Mình khuyên B để user bấm Google là vào luôn.
    if not acc:
        viewer_role_id = get_default_viewer_role_id(db)

        # username auto (bạn có thể đổi rule)
        username = (google_email.split("@")[0] if google_email else f"gg_{google_sub[:8]}")

        user = Users(
            username=username,
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
            phone_verified=True,  # hoặc False tuỳ bạn
        )
        db.add(acc)
        db.commit()
    else:
        user = db.get(Users, acc.user_id)
        if not user:
            raise HTTPException(status_code=404, detail="User không tồn tại")

    jwt = make_access_token(user.user_id)
    return TokenOut(access_token=jwt, user_id=user.user_id, username=user.username)
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


# ======================
#  QUÊN MẬT KHẨU
# ======================
@router.post("/forgot-password", status_code=200)
def forgot_password(payload: ForgotPasswordIn, db: Session = Depends(get_db)):
    if not payload.email and not payload.phone:
        raise HTTPException(status_code=400, detail="Phải nhập email hoặc số điện thoại")

    user = None
    contact = None
    channel = None

    if payload.email:
        user = db.scalar(select(Users).where(Users.email == payload.email))
        contact = payload.email
        channel = "email"
    elif payload.phone:
        user = db.scalar(select(Users).where(Users.phone == payload.phone))
        contact = payload.phone
        channel = "sdt"

    if channel == "sdt" and not user:
        raise HTTPException(status_code=404, detail="Số điện thoại này chưa được đăng ký.")

    if channel == "email" and (not user or not contact):
        return {"ok": True, "message": "Nếu tài khoản tồn tại, hệ thống đã gửi hướng dẫn đặt lại mật khẩu."}

    token = make_confirm_token(user.user_id, "reset", contact, minutes=30)
    reset_url = f"/reset-password?token={token}"

    if channel == "email":
        send_email(contact, "Đặt lại mật khẩu PlantGuard", f"Bạn đã yêu cầu đặt lại mật khẩu. Bấm link: {reset_url}")
    elif channel == "sdt":
        send_sms(contact, f"Dat lai mat khau: {reset_url}")

    return {"ok": True, "message": "Đã gửi hướng dẫn đặt lại mật khẩu."}


# ======================
#  ĐẶT LẠI MẬT KHẨU
# ======================
@router.post("/reset-password", status_code=200)
def reset_password(payload: ResetPasswordIn, db: Session = Depends(get_db)):
    try:
        data = parse_confirm_token(payload.token)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Token không hợp lệ hoặc đã hết hạn: {e}")

    uid = int(data["uid"])
    channel = data["ch"]

    if channel != "reset":
        raise HTTPException(status_code=400, detail="Token không phải token đặt lại mật khẩu")

    user = db.get(Users, uid)
    if not user:
        raise HTTPException(status_code=404, detail="Tài khoản không tồn tại")

    user.password = hash_password(payload.new_password)  # ✅ bcrypt
    user.failed_login = 0
    user.locked = None

    db.add(user)
    db.commit()

    return {"ok": True, "message": "Đặt lại mật khẩu thành công, hãy đăng nhập lại."}

@router.post("/send-email-confirm", status_code=200)
def send_email_confirm(email: str = Query(...), db: Session = Depends(get_db)):
    email = email.strip().lower()

    user = db.scalar(select(Users).where(Users.email == email))
    if not user:
        raise HTTPException(status_code=404, detail="Email này chưa được đăng ký tài khoản.")

    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.user_id == user.user_id,
        AuthAccount.provider == Provider.email,
        AuthAccount.provider_user_id == email
    ))
    if not acc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản email để xác nhận.")

    # Nếu bạn đang dùng phone_verified như cờ "verified" chung
    if acc.phone_verified:
        return {"ok": True, "message": "Email đã được xác nhận trước đó."}

    token = make_confirm_token(user.user_id, "email", email, minutes=30)

    API_URL = "http://127.0.0.1:8000"  # đổi theo domain deploy
    confirm_url = f"{API_URL}/api/v1/auth/confirm?token={token}"

    send_email(email, "Xác nhận đăng ký", f"Bấm để xác nhận email: {confirm_url}")

    return {"ok": True, "message": "Đã gửi lại link xác nhận email."}
@router.post("/send-phone-confirm", status_code=200)
def send_phone_confirm(phone: str = Query(...), db: Session = Depends(get_db)):
    user = db.scalar(select(Users).where(Users.phone == phone))
    if not user:
        raise HTTPException(status_code=404, detail="Số điện thoại này chưa được đăng ký tài khoản.")

    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.user_id == user.user_id,
        AuthAccount.provider == Provider.sdt,
        AuthAccount.provider_user_id == phone
    ))
    if not acc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài khoản SĐT để xác nhận.")

    token = make_confirm_token(user.user_id, "sdt", phone, minutes=30)
    confirm_url = f"/api/v1/auth/confirm?token={token}"

    send_sms(phone, f"Xac nhan so dien thoai: {confirm_url}")

    return {"ok": True, "message": "Đã gửi lại link xác nhận số điện thoại."}


@router.post("/forgot-password-otp")
def forgot_password_otp(payload: ForgotPasswordOTPIn, db: Session = Depends(get_db)):
    if not payload.email and not payload.phone:
        raise HTTPException(400, "Phải nhập email hoặc số điện thoại")

    # xác định user + contact
    if payload.email:
        user = db.scalar(select(Users).where(Users.email == payload.email))
        contact = payload.email.strip().lower()
        channel = "email"
    else:
        user = db.scalar(select(Users).where(Users.phone == payload.phone))
        contact = payload.phone.strip()
        channel = "sdt"

    # không tiết lộ user tồn tại
    if not user:
        return {"ok": True, "message": "Nếu tài khoản tồn tại, OTP đã được gửi"}

    # tạo otp 6 số
    otp = f"{secrets.randbelow(1000000):06d}"
    expires = datetime.utcnow() + timedelta(minutes=5)

    # xoá OTP cũ của user
    db.execute(delete(PasswordResetOTP).where(PasswordResetOTP.user_id == user.user_id))

    db.add(PasswordResetOTP(
        user_id=user.user_id,
        contact=contact,
        otp_hash=hash_otp(otp),
        expires_at=expires
    ))
    db.commit()

    if channel == "email":
        send_email(contact, "Mã OTP đặt lại mật khẩu", f"Mã OTP của bạn là: {otp}. Hiệu lực 5 phút.")
    else:
        send_sms(contact, f"OTP dat lai mat khau: {otp} (hieu luc 5 phut)")

    return {"ok": True, "message": "OTP đã được gửi"}
@router.post("/verify-reset-otp")
def verify_reset_otp(payload: VerifyResetOTPIn, db: Session = Depends(get_db)):
    contact = payload.contact.strip().lower() if "@" in payload.contact else payload.contact.strip()

    record = db.scalar(select(PasswordResetOTP).where(PasswordResetOTP.contact == contact))
    if not record:
        raise HTTPException(400, "OTP không hợp lệ")

    if record.expires_at < datetime.utcnow():
        raise HTTPException(400, "OTP đã hết hạn")

    if record.attempts >= 5:
        raise HTTPException(429, "Nhập sai quá nhiều lần")

    if not verify_otp(payload.otp, record.otp_hash):
        record.attempts += 1
        db.commit()
        raise HTTPException(400, "OTP không đúng")

    # OTP đúng → tạo reset_token 10 phút
    reset_token = make_confirm_token(record.user_id, "reset", record.contact, minutes=10)

    db.delete(record)
    db.commit()

    return {"ok": True, "reset_token": reset_token}
