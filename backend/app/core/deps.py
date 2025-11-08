from fastapi import Depends, HTTPException, status
from typing import Optional

# Fake dependency - chỉ để không lỗi khi import
def current_user():
    """
    Dependency giả lập người dùng đang đăng nhập.
    Tạm thời trả về user_id = 1 (hoặc None).
    Sau này team auth sẽ thay thế.
    """
    return {"user_id": 1, "role": "viewer"}
