from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.core.db import get_db
from app.schemas.users import UserCreate, UserUpdate, UserOut, RoleOut, AssignRoleIn
from app.services import users_service as svc

router = APIRouter(prefix="/users", tags=["Users"])

def _to_out(u) -> UserOut:
    roles = [RoleOut.from_orm(ur.role) for ur in u.roles]
    return UserOut(
        user_id=u.user_id, username=u.username, email=u.email, phone=u.phone,
        address=u.address, status=u.status, roles=roles
    )

@router.get("/", response_model=List[UserOut])
def list_users(db: Session = Depends(get_db)):
    return [_to_out(u) for u in svc.list_users(db)]

@router.get("/{user_id}", response_model=UserOut)
def get_user(user_id: int, db: Session = Depends(get_db)):
    u = svc.get_user(db, user_id)
    if not u: raise HTTPException(status_code=404, detail="Không tìm thấy user")
    return _to_out(u)

@router.post("/", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def create_user(body: UserCreate, db: Session = Depends(get_db)):
    try:
        u = svc.create_user(db, body)
        return _to_out(u)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{user_id}", response_model=UserOut)
def update_user(user_id: int, body: UserUpdate, db: Session = Depends(get_db)):
    try:
        u = svc.update_user(db, user_id, body)
        return _to_out(u)
    except LookupError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    try:
        svc.delete_user(db, user_id)
        return
    except LookupError as e:
        raise HTTPException(status_code=404, detail=str(e))

@router.get("/{user_id}/roles", response_model=List[RoleOut])
def list_roles(user_id: int, db: Session = Depends(get_db)):
    u = svc.get_user(db, user_id)
    if not u: raise HTTPException(status_code=404, detail="Không tìm thấy user")
    return [RoleOut.from_orm(ur.role) for ur in u.roles]

@router.post("/{user_id}/roles", status_code=status.HTTP_201_CREATED)
def assign_role(user_id: int, body: AssignRoleIn, db: Session = Depends(get_db)):
    try:
        svc.assign_role(db, user_id, body.role_id)
        return {"message": "Đã gán role"}
    except (LookupError, ValueError) as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.delete("/{user_id}/roles/{role_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_role(user_id: int, role_id: int, db: Session = Depends(get_db)):
    try:
        svc.remove_role(db, user_id, role_id)
        return
    except LookupError as e:
        raise HTTPException(status_code=404, detail=str(e))
