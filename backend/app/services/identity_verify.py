# app/services/identity_verify.py

import re
import json
import urllib.parse
import urllib.request

from typing import Optional, Tuple
import jwt
from datetime import datetime, timezone
from app.core.config import settings


def phone_exists_really(phone: str) -> bool:
    """Kiểm tra cơ bản số điện thoại (chỉ số, 9–15 ký tự)."""
    return bool(re.fullmatch(r"\d{9,15}", phone or ""))


def verify_google_id_token(id_token: str) -> Optional[Tuple[str, Optional[str]]]:
    """
    DEV: Giải mã id_token KHÔNG kiểm chữ ký để lấy (sub, email) + kiểm tra aud/exp.
    Trả về (google_sub, email|None) nếu hợp lệ, ngược lại None.
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

    if aud != settings.GOOGLE_CLIENT_ID:
        return None

    exp = data.get("exp")
    if exp:
        now = datetime.now(timezone.utc).timestamp()
        if now > float(exp):
            return None

    return (str(sub), email)


def verify_facebook_access_token(access_token: str) -> Optional[str]:
    """
    Xác thực access_token thật với Facebook Graph API.
    Trả về facebook_user_id nếu hợp lệ, ngược lại None.
    """
    if not access_token or len(access_token) < 10:
        return None

    if not settings.FB_APP_ID or not settings.FB_APP_SECRET:
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
