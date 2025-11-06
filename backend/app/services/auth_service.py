from sqlalchemy.orm import Session
from firebase_admin import auth as fb_auth
from app.models.users import Users, AuthAccounts, Provider, UserStatus
from app.core.jwt import create_access_token

def login_with_firebase_idtoken(db: Session, id_token: str) -> dict:
    decoded = fb_auth.verify_id_token(id_token)  # raise nếu token không hợp lệ
    uid   = decoded.get("uid")
    email = decoded.get("email")
    name  = decoded.get("name")
    provider_id = decoded.get("firebase", {}).get("sign_in_provider")  # google.com / facebook.com / password / phone

    # upsert Users
    user = None
    if email:
        user = db.query(Users).filter(Users.email == email).first()
    if not user:
        user = Users(email=email, username=name, status=UserStatus.active)
        db.add(user); db.commit(); db.refresh(user)

    # map provider
    if provider_id == "google.com":
        pv = Provider.gg
    elif provider_id == "facebook.com":
        pv = Provider.fb
    elif provider_id == "phone":
        pv = Provider.sđt
    else:
        pv = Provider.sđt  # hoặc None tuỳ bạn

    # upsert auth_accounts
    aa = db.query(AuthAccounts).filter(
        AuthAccounts.user_id == user.user_id,
        AuthAccounts.provider == pv
    ).first()
    if not aa:
        aa = AuthAccounts(user_id=user.user_id, provider=pv, provider_user_id=uid)
        db.add(aa); db.commit()

    # phát JWT nội bộ (giữ nguyên hệ thống của bạn)
    token = create_access_token({"sub": str(user.user_id)})
    return {"access_token": token, "user_id": user.user_id}
