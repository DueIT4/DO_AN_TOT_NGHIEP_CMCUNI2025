from pydantic import BaseModel, Field, EmailStr
from typing import Optional
from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
# Đăng ký SĐT
class RegisterPhoneIn(BaseModel):
    username: str = Field(min_length=2, max_length=191)
    phone: str = Field(min_length=8, max_length=30)
    password: str = Field(min_length=6, max_length=255)

# Đăng ký Google (cần id_token để kiểm “có thực”)
class RegisterGoogleIn(BaseModel):
    id_token: str = Field(min_length=10)   # token Google
    username: str = Field(min_length=2, max_length=191)  # tên hiển thị

# Đăng ký Facebook (cần access_token để kiểm “có thực”)
class RegisterFacebookIn(BaseModel):
    access_token: str = Field(min_length=10)  # token Facebook
    username: str = Field(min_length=2, max_length=191)

class RegisterOut(BaseModel):
    user_id: int
    username: Optional[str] = None
    phone: Optional[str] = None
    provider: Optional[str] = None
    message: str
class LoginPhoneIn(BaseModel):
    phone: str = Field(min_length=8, max_length=30)
    password: str = Field(min_length=6, max_length=255)

class LoginIn(BaseModel):
    """Đăng nhập bằng email hoặc phone"""
    email: Optional[str] = None
    phone: Optional[str] = None
    password: str = Field(min_length=6, max_length=255)
    
    def model_post_init(self, __context):
        """Kiểm tra phải có ít nhất email hoặc phone"""
        if not self.email and not self.phone:
            raise ValueError('Phải nhập email hoặc số điện thoại')

class SocialLoginIn(BaseModel):
    # google: id_token, facebook: access_token
    token: str = Field(min_length=10)

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str | None = None

class ForgotPasswordIn(BaseModel):
    email: Optional[EmailStr] = None
    phone: Optional[str] = None

    @field_validator("email", "phone")
    @classmethod
    def at_least_one(cls, v, info):
        # validator này chạy từng field, nên ta check ở ngoài
        return v

    @property
    def has_any(self) -> bool:
        return bool(self.email or self.phone)

# app/schemas/auth.py
class ForgotPasswordOTPIn(BaseModel):
    email: str | None = None
    phone: str | None = None

class ResetPasswordIn(BaseModel):
    token: str
    new_password: str

    @field_validator("new_password")
    @classmethod
    def password_min_length(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Mật khẩu mới phải ít nhất 6 ký tự")
        return v
    
class VerifyResetOTPIn(BaseModel):
    contact: str
    otp: str
class RegisterEmailIn(BaseModel):
    username: str = Field(..., min_length=1)
    email: EmailStr
    password: str = Field(..., min_length=6)