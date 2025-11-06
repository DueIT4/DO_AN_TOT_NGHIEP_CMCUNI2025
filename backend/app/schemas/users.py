from pydantic import BaseModel, EmailStr, Field
from typing import Optional, List
from app.models.users import UserStatus, RoleType

# ---- Role ----
class RoleOut(BaseModel):
    role_id: int
    role_type: RoleType
    name: str
    description: Optional[str] = None
    class Config: from_attributes = True

# ---- Users ----
class UserCreate(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: str = Field(min_length=6)
    full_name: Optional[str] = None
    address: Optional[str] = None

class UserUpdate(BaseModel):
    username: Optional[str] = None
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    password: Optional[str] = None
    address: Optional[str] = None
    status: Optional[UserStatus] = None
    avt_url: Optional[str] = None

class UserOut(BaseModel):
    user_id: int
    username: Optional[str]
    email: Optional[EmailStr]
    phone: Optional[str]
    address: Optional[str]
    status: UserStatus
    roles: List[RoleOut] = []
    class Config: from_attributes = True

# ---- Assign role ----
class AssignRoleIn(BaseModel):
    role_id: int
