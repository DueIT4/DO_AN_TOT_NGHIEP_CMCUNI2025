import bcrypt

_BCRYPT_ROUNDS = 12  # mức phổ biến

def hash_password(raw: str) -> str:
    raw_b = raw.encode("utf-8")
    salt = bcrypt.gensalt(rounds=_BCRYPT_ROUNDS)
    return bcrypt.hashpw(raw_b, salt).decode("utf-8")

def verify_password(raw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(raw.encode("utf-8"), hashed.encode("utf-8"))
    except Exception:
        return False
