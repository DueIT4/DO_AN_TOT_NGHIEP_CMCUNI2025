# app/main.py
from fastapi import FastAPI
from fastapi.responses import JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.models import user, role, auth_account, notification 
from app.api.v1.routes_health import router as health_router
from app.api.v1.routes_detect import router as detect_router
from app.api.v1.routes_auth import router as auth_router
from app.api.v1.routes_users import router as users_router
from fastapi.staticfiles import StaticFiles
from app.core.config import settings
from app.api.v1.routes_me import router as me_router
from app.api.v1.routes_support import router as support_router
from app.api.v1.routes_notifications import router as notifications_router
from sqlalchemy.orm import configure_mappers
from fastapi.middleware.cors import CORSMiddleware
configure_mappers()
from pathlib import Path

app = FastAPI(
    title=settings.APP_NAME,
    docs_url="/docs",           # ép bật Swagger
    redoc_url="/redoc",         # (tuỳ chọn)
    openapi_url="/openapi.json" # schema
)

# CORS configuration
# Khi CORS_ORIGINS là ["*"], không thể dùng allow_credentials=True
# Nên dùng regex để match localhost ports và vẫn giữ credentials
cors_origins = settings.CORS_ORIGINS
if cors_origins == ["*"]:
    # Dùng regex để match localhost ports, cho phép credentials
    app.add_middleware(
        CORSMiddleware,
        allow_origin_regex=settings.CORS_ORIGIN_REGEX,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
else:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_origin_regex=settings.CORS_ORIGIN_REGEX,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

app.include_router(health_router, prefix=settings.API_V1)
app.include_router(detect_router, prefix=settings.API_V1)
app.include_router(auth_router, prefix=settings.API_V1)
app.include_router(users_router, prefix=settings.API_V1)
app.include_router(me_router, prefix=settings.API_V1)
app.include_router(support_router, prefix=settings.API_V1)
app.include_router(notifications_router, prefix=settings.API_V1)

@app.get("/")
def root():
    # Trỏ đúng /docs (KHÔNG phải /api/v1/docs)
    return JSONResponse({"name": settings.APP_NAME, "health": "ok", "docs": "/docs"})

@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    return Response(status_code=204)

@app.get("/.well-known/appspecific/com.chrome.devtools.json", include_in_schema=False)
def chrome_devtools_probe():
    return Response(status_code=204)
# Tạo thư mục media/avatars nếu chưa có
Path("./media/avatars").mkdir(parents=True, exist_ok=True)
# Cho phép truy cập file tĩnh qua /media
app.mount("/media", StaticFiles(directory="media"), name="media")

# support uploads (đính kèm trong hỗ trợ)
Path("uploads/support").mkdir(parents=True, exist_ok=True)  
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads") 