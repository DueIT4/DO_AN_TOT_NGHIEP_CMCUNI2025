# app/services/confirm_token.py
from datetime import datetime, timedelta, timezone
import jwt  # PyJWT
from app.core.config import settings

def make_confirm_token(user_id: int, channel: str, value: str, minutes: int = 30) -> str:
    """
    Tạo JWT token xác nhận.
    channel: 'sđt' | 'email' | 'fb' | 'gg'
    value:   phone/email/facebook_id/google_sub
    """
    now = datetime.now(timezone.utc)
    payload = {
        "sub": "confirm",
        "uid": user_id,
        "ch": channel,
        "val": value,
        "iat": now,
        "exp": now + timedelta(minutes=minutes),
    }
    return jwt.encode(payload, settings.JWT_SECRET, algorithm=settings.JWT_ALG)

def parse_confirm_token(token: str) -> dict:
    """Giải mã & xác thực token xác nhận."""
    return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALG])
