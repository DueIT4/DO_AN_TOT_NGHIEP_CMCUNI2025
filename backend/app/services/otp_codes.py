# app/services/otp_codes.py
import hmac
from app.services.passwords import hash_password, verify_password

def hash_otp(otp: str) -> str:
    return hash_password(otp)

def verify_otp(otp: str, otp_hash: str) -> bool:
    # dùng verify_password (bcrypt) để so
    return verify_password(otp, otp_hash)
