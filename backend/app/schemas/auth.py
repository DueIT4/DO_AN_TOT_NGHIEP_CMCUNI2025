from pydantic import BaseModel, Field, EmailStr
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

class SocialLoginIn(BaseModel):
    # google: id_token, facebook: access_token
    token: str = Field(min_length=10)

class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    username: str | None = None