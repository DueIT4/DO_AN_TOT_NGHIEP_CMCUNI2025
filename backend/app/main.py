# app/main.py
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.models import user, role, auth_account, notification 
from app.api.v1.routes_health import router as health_router
from app.api.v1.routes_detect import router as detect_router
from app.api.v1.routes_auth import router as auth_router
from app.api.v1.routes_users import router as users_router
from fastapi.staticfiles import StaticFiles

# Subclass StaticFiles to avoid raising an unhandled OSError on Windows
# when path contains invalid filename characters (for example when a
# client mistakenly requests `/media/hls/temp-<key>/index.m3u8`).
# We convert those OSError cases to a 404 HTTP response instead of
# letting the ASGI app crash with a 500.
class SafeStaticFiles(StaticFiles):
    def lookup_path(self, path):
        try:
            return super().lookup_path(path)
        except OSError:
            # translate invalid filename/OS errors into a normal 404
            raise HTTPException(status_code=404, detail="File not found")
from app.core.config import settings
from app.api.v1.routes_me import router as me_router
from app.api.v1.routes_support import router as support_router
from app.api.v1.routes_notifications import router as notifications_router
from app.api.v1.routes_chatbot import router as chatbot_router
from app.api.v1.routes_devices import router as devices_router
from app.api.v1.routes_streams import router as streams_router

from app.api.v1.routes_detect import router as detect_router

from sqlalchemy.orm import configure_mappers
from fastapi.middleware.cors import CORSMiddleware

import app.models

configure_mappers()
from pathlib import Path
from fastapi.responses import FileResponse

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
app.include_router(chatbot_router, prefix=settings.API_V1)
app.include_router(devices_router, prefix=settings.API_V1)
app.include_router(streams_router, prefix=settings.API_V1)

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
app.mount("/media", SafeStaticFiles(directory="media"), name="media")

# support uploads (đính kèm trong hỗ trợ)
Path("uploads/support").mkdir(parents=True, exist_ok=True)  
app.mount("/uploads", SafeStaticFiles(directory="uploads"), name="uploads")


# Ensure static media responses include CORS headers and correct content-type
# for HLS playlists so web clients (hls.js / browsers) can fetch playlists and
# segments without being blocked by CORS or wrong mime types.
@app.middleware("http")
async def media_cors_middleware(request, call_next):
    response = await call_next(request)
    path = request.url.path or ""
    # Only modify responses for our static media endpoints
    if path.startswith("/media/") or path.startswith("/uploads/"):
        # Add permissive CORS for media. In production you should restrict origin.
        if "access-control-allow-origin" not in response.headers:
            response.headers["Access-Control-Allow-Origin"] = "*"
            response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
            response.headers["Access-Control-Allow-Headers"] = "Range,Accept,Content-Type"
            response.headers["Access-Control-Expose-Headers"] = "Content-Length,Content-Range,Accept-Ranges"

        # Ensure playlist has correct mime-type
        if path.endswith('.m3u8'):
            response.headers["Content-Type"] = "application/vnd.apple.mpegurl"

    return response


# Serve a tiny helper page for web HLS player (iframe). This file is
# stored in the frontend project under `frontend/mobile_web_flutter/web/hls_player.html`.
@app.get('/hls_player.html', include_in_schema=False)
def serve_hls_player():
    # prefer local copied file in backend if present
    possible_backend = Path('web') / 'hls_player.html'
    if possible_backend.exists():
        return FileResponse(str(possible_backend.resolve()), media_type='text/html')

    # fallback to frontend project file
    frontend_path = Path(__file__).resolve().parents[3] / 'frontend' / 'mobile_web_flutter' / 'web' / 'hls_player.html'
    if frontend_path.exists():
        return FileResponse(str(frontend_path), media_type='text/html')

    return FileResponse(str(possible_backend), media_type='text/html')

# ========== AUTO SCAN SCHEDULER ==========
from app.services.scheduler_service import start_scheduler
import logging

logger = logging.getLogger(__name__)

@app.on_event("startup")
async def startup_event():
    """Khởi động scheduler khi ứng dụng khởi động"""
    try:
        start_scheduler()
        logger.info("✅ Auto scan scheduler đã khởi động")
    except Exception as e:
        logger.error(f"❌ Lỗi khi khởi động scheduler: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    """Dừng scheduler khi ứng dụng tắt"""
    from app.services.scheduler_service import stop_scheduler
    try:
        stop_scheduler()
        logger.info("✅ Auto scan scheduler đã dừng")
    except Exception as e:
        logger.error(f"❌ Lỗi khi dừng scheduler: {e}") 