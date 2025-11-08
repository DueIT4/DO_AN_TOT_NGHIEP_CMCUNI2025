from typing import List, Optional
from sqlalchemy.orm import Session, joinedload
from passlib.hash import bcrypt

from app.models.users import Users, Role, UserRole, UserStatus
from app.schemas.users import UserCreate, UserUpdate

def _query_user_with_roles(db: Session):
    return db.query(Users).options(joinedload(Users.roles).joinedload(UserRole.role))

def list_users(db: Session) -> List[Users]:
    return _query_user_with_roles(db).all()

def get_user(db: Session, user_id: int) -> Optional[Users]:
    return _query_user_with_roles(db).filter(Users.user_id == user_id).first()

def create_user(db: Session, data: UserCreate) -> Users:
    if data.email and db.query(Users).filter(Users.email == data.email).first():
        raise ValueError("Email đã tồn tại")
    if data.phone and db.query(Users).filter(Users.phone == data.phone).first():
        raise ValueError("Số điện thoại đã tồn tại")
    if data.username and db.query(Users).filter(Users.username == data.username).first():
        raise ValueError("Username đã tồn tại")

    u = Users(
        username=data.username,
        email=data.email,
        phone=data.phone,
        password=bcrypt.hash(data.password),
        address=data.address,
        status=UserStatus.active,
    )
    db.add(u); db.commit(); db.refresh(u)
    return u

def update_user(db: Session, user_id: int, data: UserUpdate) -> Users:
    u = db.query(Users).get(user_id)
    if not u: raise LookupError("Không tìm thấy user")

    if data.email and data.email != u.email and db.query(Users).filter(Users.email == data.email).first():
        raise ValueError("Email đã tồn tại")
    if data.phone and data.phone != u.phone and db.query(Users).filter(Users.phone == data.phone).first():
        raise ValueError("Số điện thoại đã tồn tại")
    if data.username and data.username != u.username and db.query(Users).filter(Users.username == data.username).first():
        raise ValueError("Username đã tồn tại")

    for k, v in data.dict(exclude_unset=True).items():
        if k == "password" and v:
            setattr(u, "password", bcrypt.hash(v))
        else:
            setattr(u, k, v)
    db.commit(); db.refresh(u)
    return u

def delete_user(db: Session, user_id: int) -> None:
    u = db.query(Users).get(user_id)
    if not u: raise LookupError("Không tìm thấy user")
    db.delete(u); db.commit()

def assign_role(db: Session, user_id: int, role_id: int) -> None:
    u = db.query(Users).get(user_id)
    if not u: raise LookupError("Không tìm thấy user")
    r = db.query(Role).get(role_id)
    if not r: raise LookupError("Không tìm thấy role")
    if db.query(UserRole).filter(UserRole.user_id==user_id, UserRole.role_id==role_id).first():
        raise ValueError("User đã có role này")
    db.add(UserRole(user_id=user_id, role_id=role_id)); db.commit()

def remove_role(db: Session, user_id: int, role_id: int) -> None:
    ur = db.query(UserRole).filter(UserRole.user_id==user_id, UserRole.role_id==role_id).first()
    if not ur: raise LookupError("Không tìm thấy role trên user này")
    db.delete(ur); db.commit()
