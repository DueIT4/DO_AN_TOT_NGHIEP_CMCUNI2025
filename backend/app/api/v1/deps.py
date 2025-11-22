# app/api/v1/deps.py
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select

from app.core.database import get_db
from app.services.auth_jwt import decode_access_token
from app.models.user import Users
from app.models.role import RoleType  # enum: support, viewer, admin, support_admin

auth_scheme = HTTPBearer(auto_error=False)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(auth_scheme),
    db: Session = Depends(get_db),
) -> Users:
    if not creds or creds.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Thiếu hoặc sai Authorization header",
        )

    payload = decode_access_token(creds.credentials)
    uid = int(payload["uid"])

    user = db.scalar(
        select(Users)
        .options(joinedload(Users.role))
        .where(Users.user_id == uid)
    )
    if not user:
        raise HTTPException(status_code=401, detail="Không tìm thấy user")

    if user.status != "active":
        raise HTTPException(status_code=403, detail="Tài khoản đã bị khóa")

    return user


def get_optional_user(
    creds: HTTPAuthorizationCredentials = Depends(auth_scheme),
    db: Session = Depends(get_db),
) -> Users | None:
    """Dùng cho /detect: có token thì lấy user, không có thì trả None, không 401."""
    if not creds:
        return None

    try:
        payload = decode_access_token(creds.credentials)
        uid = int(payload["uid"])
    except Exception:
        return None

    user = db.scalar(
        select(Users)
        .options(joinedload(Users.role))
        .where(Users.user_id == uid)
    )
    return user


def _ensure_role(user: Users, allowed: set[RoleType]):
    if not user.role or user.role.role_type not in allowed:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền thực hiện thao tác này",
        )


def require_admin(current_user: Users = Depends(get_current_user)) -> Users:
    """Chỉ admin."""
    _ensure_role(current_user, {RoleType.admin})
    return current_user


def require_support(
    current_user: Users = Depends(get_current_user),
) -> Users:
    """Support (nhân viên hỗ trợ) hoặc cao hơn (support_admin, admin)."""
    _ensure_role(
        current_user,
        {RoleType.support, RoleType.support_admin, RoleType.admin},
    )
    return current_user


def require_support_admin(
    current_user: Users = Depends(get_current_user),
) -> Users:
    """Support admin hoặc admin."""
    _ensure_role(
        current_user,
        {RoleType.support_admin, RoleType.admin},
    )
    return current_user


def require_viewer_or_higher(
    current_user: Users = Depends(get_current_user),
) -> Users:
    """Bất kỳ user nào đã đăng nhập (viewer trở lên)."""
    _ensure_role(
        current_user,
        {RoleType.viewer, RoleType.support, RoleType.support_admin, RoleType.admin},
    )
    return current_user


def require_roles(*roles: RoleType):
    """
    Factory cho phép tùy biến:
    Depends(require_roles(RoleType.admin, RoleType.support_admin))
    """
    allowed = set(roles)

    def dep(current_user: Users = Depends(get_current_user)) -> Users:
        _ensure_role(current_user, allowed)
        return current_user

    return dep
