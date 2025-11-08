from typing import Iterable, Callable
from fastapi import Depends, HTTPException, status
from app.api.v1.deps import get_current_user
from app.models.user import Users
from app.models.role import RoleType

# ===== 4.1) Kiểm tra theo vai trò =====
def require_roles(*allowed_roles: RoleType) -> Callable:
    def _checker(user: Users = Depends(get_current_user)) -> Users:
        user_role = user.role.role_type if user.role else None
        if user_role not in allowed_roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Không đủ quyền")
        return user
    return _checker

# ===== 4.2) Kiểm tra theo 'tên quyền' =====
# Quy ước quyền theo yêu cầu bạn đưa ra:
# - admin: toàn bộ
# - support_admin: toàn bộ TRỪ hỗ trợ khách hàng
# - support: chỉ nghiệp vụ hỗ trợ KH
# - viewer: người dùng thường (chỉ xem/chỉnh sửa chính mình)
PERMISSIONS = {
    # Quản lý user
    "users:list":       {RoleType.admin, RoleType.support_admin},
    "users:create":     {RoleType.admin, RoleType.support_admin},
    "users:update":     {RoleType.admin, RoleType.support_admin},
    "users:delete":     {RoleType.admin}, 

    # Quản lý thiết bị/hệ thống (ví dụ)
    "devices:*":        {RoleType.admin, RoleType.support_admin},

    # Hỗ trợ khách hàng
    "support:read":     {RoleType.admin, RoleType.support},
    "support:reply":    {RoleType.admin, RoleType.support},
    "support:manage":   {RoleType.admin, RoleType.support},  # support_admin bị loại khỏi module support
    
    "noti:create": {RoleType.admin, RoleType.support_admin},
    "noti:list":   {RoleType.admin, RoleType.support_admin},
    "noti:delete": {RoleType.admin, RoleType.support_admin},

    # Viewer/self
    "self:read":        {RoleType.admin, RoleType.support_admin, RoleType.support, RoleType.viewer},
    "self:update":      {RoleType.admin, RoleType.support_admin, RoleType.support, RoleType.viewer},
}

def require_perm(perm_name: str) -> Callable:
    def _checker(user: Users = Depends(get_current_user)) -> Users:
        user_role = user.role.role_type if user.role else None
        if user_role == RoleType.admin:
            return user  # admin luôn pass
        allowed = PERMISSIONS.get(perm_name, set())
        if user_role not in allowed:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail=f"Thiếu quyền: {perm_name}")
        return user
    return _checker
