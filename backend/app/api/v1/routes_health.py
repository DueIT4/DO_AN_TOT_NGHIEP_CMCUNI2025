from fastapi import APIRouter
from app.core.database import ping_db

router = APIRouter()

@router.get("/healthz")
def healthz():
    return {"status": "ok"}

@router.get("/health")
def health():
    return {"db": "connected" if ping_db() else "disconnected"}
