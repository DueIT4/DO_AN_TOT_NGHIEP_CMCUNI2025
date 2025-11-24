# app/services/identity_verify.py
# DEV helpers:
# - Phone "có thực" nếu match pattern số.
# - Google:
#     + Web: verify bằng ACCESS TOKEN -> gọi Google UserInfo (khuyên dùng cho Flutter web)
#     + Mobile/native: có thể verify ID TOKEN (giải mã không chữ ký cho DEV)
# - Facebook: verify access_token với Graph API.

from typing import Optional, Tuple
from datetime import datetime, timezone
import re
import json
import urllib.parse
import urllib.request

import requests      # <- cần có trong requirements.txt
import jwt           # dùng cho DEV id_token

from app.core.config import settings


# ---------------- Phone ----------------
def phone_exists_really(phone: str) -> bool:
    """Kiểm tra cơ bản số điện thoại (chỉ số, 9–15 ký tự)."""
    return bool(re.fullmatch(r"\d{9,15}", phone or ""))


# ---------------- Google (WEB) ----------------
def verify_google_access_token(access_token: str) -> Optional[Tuple[str, Optional[str]]]:
    """
    Xác thực Google access_token bằng cách gọi UserInfo.
    Trả về (google_sub, email|None) nếu hợp lệ, ngược lại None.
    Dùng CHO WEB (Flutter web).
    """
    if not access_token or len(access_token) < 10:
        return None
    try:
        r = requests.get(
            "https://www.googleapis.com/oauth2/v3/userinfo",
            headers={"Authorization": f"Bearer {access_token}"},
            timeout=10,
        )
        if r.status_code != 200:
            return None
        info = r.json()  # chứa: sub, email, email_verified, name, picture, ...
        sub = info.get("sub")
        email = info.get("email")
        if not sub:
            return None
        return (str(sub), email)
    except Exception:
        return None


# ---------------- Google (MOBILE/DEV) ----------------
def verify_google_id_token(id_token: str) -> Optional[Tuple[str, Optional[str]]]:
    """
    DEV: Giải mã id_token KHÔNG kiểm chữ ký để lấy (sub, email) + kiểm tra aud/exp.
    Trả về (google_sub, email|None) nếu hợp lệ, ngược lại None.
    (Dùng cho mobile/native; web thường không có id_token)
    """
    if not id_token or len(id_token) < 10:
        return None
    try:
        data = jwt.decode(
            id_token,
            options={"verify_signature": False, "verify_exp": False},
            algorithms=["RS256", "HS256", "none"],
            audience=None,
        )
    except Exception:
        return None

    aud = data.get("aud")
    sub = data.get("sub")
    email = data.get("email")
    if not aud or not sub:
        return None

    # So khớp Client ID của bạn (đặt trong .env) để hạn chế sai nguồn
    if aud != settings.GOOGLE_CLIENT_ID:
        return None

    exp = data.get("exp")
    if exp:
        now = datetime.now(timezone.utc).timestamp()
        if now > float(exp):
            return None

    return (str(sub), email)


# ---------------- Facebook ----------------
def verify_facebook_access_token(access_token: str) -> Optional[str]:
    """
    Xác thực access_token thật với Facebook Graph API.
    Trả về facebook_user_id nếu hợp lệ, ngược lại None.
    """
    if not access_token or len(access_token) < 10:
        return None

    app_token = f"{settings.FB_APP_ID}|{settings.FB_APP_SECRET}"
    params = urllib.parse.urlencode({
        "input_token": access_token,
        "access_token": app_token
    })
    url = f"https://graph.facebook.com/debug_token?{params}"

    try:
        with urllib.request.urlopen(url, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None

    info = (data or {}).get("data") or {}
    is_valid = info.get("is_valid")
    app_id = info.get("app_id")
    fb_user_id = info.get("user_id")

    if not is_valid or str(app_id) != str(settings.FB_APP_ID):
        return None
    return str(fb_user_id)
