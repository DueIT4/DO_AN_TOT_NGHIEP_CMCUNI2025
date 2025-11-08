from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.core.db import get_db
from app.core.firebase_admin import init_firebase
from app.services.auth_service import login_with_firebase_idtoken

router = APIRouter(prefix="/auth", tags=["Auth"])

@router.post("/firebase")
def login_with_firebase(id_token: str, db: Session = Depends(get_db)):
    try:
        init_firebase()
        return login_with_firebase_idtoken(db, id_token)
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {e}")
