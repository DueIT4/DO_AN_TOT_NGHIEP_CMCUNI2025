from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from sqlalchemy import select, update, and_

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
    ResetPasswordIn,
)
from app.models.user import Users, UserStatus
from app.models.auth_account import AuthAccount, Provider
from app.services.confirm_token import make_confirm_token, parse_confirm_token
from app.services.notifier import send_sms, send_email, send_facebook_dm
from app.services.auth_jwt import make_access_token
from app.models.role import Role, RoleType
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


# ===== 3) Đăng ký bằng FACEBOOK =====
@router.post("/register/facebook", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
def register_facebook(payload: RegisterFacebookIn, db: Session = Depends(get_db)):
    fb_uid = verify_facebook_access_token(payload.access_token)
    if not fb_uid:
        raise HTTPException(status_code=400, detail="Vui lòng nhập đúng")

    if db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.fb,
        AuthAccount.provider_user_id == fb_uid
    )):
        raise HTTPException(status_code=409, detail="Facebook đã tồn tại")

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

    token = make_confirm_token(user.user_id, "fb", fb_uid, minutes=30)
    confirm_url = f"/api/v1/auth/confirm?token={token}"
    send_facebook_dm(fb_uid, f"Ban da dang ky. Xac nhan tai khoan: {confirm_url}")

    return RegisterOut(
        user_id=user.user_id,
        username=user.username,
        provider="fb",
        message="Đã gửi xác nhận qua Facebook DM."
    )


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
    verified = verify_google_id_token(payload.token)
    if not verified:
        raise HTTPException(status_code=400, detail="Token Google không hợp lệ")
    google_sub, _email = verified

    acc = db.scalar(select(AuthAccount).where(
        AuthAccount.provider == Provider.gg,
        AuthAccount.provider_user_id == google_sub
    ))
    if not acc:
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


