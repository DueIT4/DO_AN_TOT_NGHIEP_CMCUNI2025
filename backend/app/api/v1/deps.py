# app/api/v1/deps.py
from __future__ import annotations

import logging
from typing import Optional, Set

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session, joinedload
from sqlalchemy import select

from app.core.database import get_db
from app.services.auth_jwt import decode_access_token
from app.models.user import Users
from app.models.role import RoleType  # enum: support, viewer, admin, support_admin

logger = logging.getLogger("authz")
auth_scheme = HTTPBearer(auto_error=False)

# ✅ Chỉ 1 message chung chung để FE không cần sửa
_FORBIDDEN_MSG = "Bạn không có quyền thực hiện thao tác này"


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
) -> Optional[Users]:
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


def _user_role_type(user: Users) -> Optional[RoleType]:
    return getattr(user.role, "role_type", None)


def _ensure_role(user: Users, allowed: Set[RoleType]) -> None:
    role_type = _user_role_type(user)
    if role_type not in allowed:
        # ✅ log đủ để debug BE (FE vẫn chỉ nhận message chung)
        logger.warning(
            "FORBIDDEN uid=%s role=%s allowed=%s",
            getattr(user, "user_id", None),
            getattr(role_type, "value", str(role_type)),
            [r.value for r in allowed],
        )
        raise HTTPException(status_code=403, detail=_FORBIDDEN_MSG)


# ======================= ROLE DEPENDENCIES =======================

def require_admin(current_user: Users = Depends(get_current_user)) -> Users:
    """Chỉ admin."""
    _ensure_role(current_user, {RoleType.admin})
    return current_user


def require_support_page(current_user: Users = Depends(get_current_user)) -> Users:
    """
    ✅ Trang hỗ trợ khách hàng:
    - support hoặc admin
    - support_admin KHÔNG được vào (đúng theo yêu cầu của bạn)
    """
    _ensure_role(current_user, {RoleType.support, RoleType.admin})
    return current_user


def require_support_admin_area(current_user: Users = Depends(get_current_user)) -> Users:
    """
    ✅ Khu quản trị (trừ hỗ trợ):
    - support_admin hoặc admin
    - support KHÔNG được vào
    """
    _ensure_role(current_user, {RoleType.support_admin, RoleType.admin})
    return current_user


def require_viewer_or_higher(current_user: Users = Depends(get_current_user)) -> Users:
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


# ======================= BACKWARD-COMPAT ALIASES =======================
# Nếu code cũ của bạn đang import require_support / require_support_admin,
# thì dùng alias để đỡ phải sửa nhiều.
# (Bạn có thể bỏ alias này nếu muốn refactor cho rõ ràng.)

# "support" theo đúng nghĩa trang hỗ trợ
require_support = require_support_page

# "support_admin" theo đúng nghĩa khu admin (trừ hỗ trợ)
require_support_admin = require_support_admin_area
