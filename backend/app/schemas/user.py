from pydantic import BaseModel, Field, EmailStr, field_validator
from typing import Optional
from pydantic import BaseModel
from typing import List

# Dùng khi tạo mới
class UserCreate(BaseModel):
    username: str = Field(..., min_length=3, max_length=191)
    phone: str = Field(..., min_length=6, max_length=30)
    password: str = Field(..., min_length=6, max_length=255)

    # các trường có thể để null
    email: Optional[EmailStr] = None
    avt_url: Optional[str] = None
    address: Optional[str] = None

    @field_validator("phone")
    @classmethod
    def only_digits(cls, v: str) -> str:
        # bạn có thể nới lỏng quy tắc nếu cần (ví dụ cho phép +84)
        if not v.strip().isdigit():
            raise ValueError("Số điện thoại chỉ gồm chữ số")
        return v.strip()

# Dùng để trả về sau khi tạo
class UserOut(BaseModel):
    user_id: int
    username: str
    phone: str
    email: Optional[str] = None
    avt_url: Optional[str] = None
    address: Optional[str] = None
    status: str
    role_type: Optional[str] = None

    class Config:
        from_attributes = True
class UserListOut(BaseModel):
    total: int
    items: List[UserOut]

    class Config:
        from_attributes = True