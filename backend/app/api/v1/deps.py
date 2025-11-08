from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select
from app.core.database import get_db
from app.services.auth_jwt import decode_access_token
from app.models.user import Users
from app.models.role import RoleType

auth_scheme = HTTPBearer(auto_error=False)

def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(auth_scheme),
    db: Session = Depends(get_db),
) -> Users:
    if not creds or creds.scheme.lower() != "bearer":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Thiếu hoặc sai Authorization header")
    payload = decode_access_token(creds.credentials)
    uid = int(payload["uid"])
    user = db.scalar(
        select(Users).options(joinedload(Users.role)).where(Users.user_id == uid)
    )
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Không tìm thấy user")
    return user
