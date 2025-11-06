import os, time, jwt  # pip install pyjwt
SECRET = os.getenv("APP_JWT_SECRET", "dev-secret")
ALGO   = "HS256"
EXPIRES = 60 * 60 * 24  # 1 day

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    to_encode.update({"exp": int(time.time()) + EXPIRES})
    return jwt.encode(to_encode, SECRET, algorithm=ALGO)
