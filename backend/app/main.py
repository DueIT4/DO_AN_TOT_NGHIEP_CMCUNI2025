# app/main.py
from pathlib import Path
import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.staticfiles import StaticFiles
from starlette.status import HTTP_422_UNPROCESSABLE_ENTITY

from sqlalchemy.orm import configure_mappers

from app.core.config import settings

# Import models để SQLAlchemy map đầy đủ
import app.models  # noqa: F401
from app.models import user, role, auth_account  # noqa: F401

# ==== Logging ====
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Bắt buộc gọi trước khi tạo app nếu có relationships phức tạp
configure_mappers()

# ==== Routers ====
from app.api.v1.routes_health import router as health_router
from app.api.v1.routes_detect import router as detect_router
from app.api.v1.routes_auth import router as auth_router
from app.api.v1.routes_users import router as users_router
from app.api.v1.routes_me import router as me_router
from app.api.v1.routes_support import router as support_router
from app.api.v1.routes_notifications import router as notifications_router
from app.api.v1.routes_devices import router as devices_router
from app.api.v1.routes_sensors import router as sensors_router
from app.api.v1.routes_users_devices import router as users_devices_router
from app.api.v1.routes_device_logs import router as device_logs_router
from app.api.v1.routes_detection_history import router as detection_history_router
from app.api.v1.routes_dashboard import router as dashboard_router
from app.api.v1.routes_support_admin import router as support_admin_router
from app.api.v1.routes_device_types import router as routes_device_types
from app.api.v1.routes_dataset_admin import router as routes_dataset_admin

API_PREFIX = getattr(settings, "API_V1", "/api/v1")

tags_metadata = [
    {"name": "Detection", "description": "Upload/Camera → ONNX → LLM → lưu DB."},
    {"name": "Notifications", "description": "Thông báo hệ thống cho người dùng."},
    {"name": "Support", "description": "Ticket & hội thoại hỗ trợ khách hàng."},
    {"name": "Users", "description": "Quản lý người dùng & hồ sơ cá nhân."},
    {"name": "default", "description": "Health & tiện ích."},
    {"name": "Device", "description": "Thiết bị."},
]

app = FastAPI(
    title=getattr(settings, "APP_NAME", "ZestGuard API"),
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    openapi_tags=tags_metadata,
)

# ==== Middlewares ====
# ⚠️ Dev: KHÔNG dùng "*" nếu allow_credentials=True (browser sẽ chặn CORS)
# Hãy whitelist origin của Flutter Web dev server (port có thể thay đổi)
DEFAULT_DEV_ORIGINS = [
    "http://localhost:61164",
    "http://127.0.0.1:61164",
    "http://localhost:5173",
    "http://127.0.0.1:5173",
    "http://localhost:3000",
    "http://127.0.0.1:3000",
]

cors_origins = getattr(settings, "CORS_ORIGINS", None)
cors_origin_regex = getattr(settings, "CORS_ORIGIN_REGEX", None)

# Nếu settings.CORS_ORIGINS không set hoặc để ["*"] thì dùng danh sách dev ở trên
if not cors_origins or cors_origins == ["*"] or cors_origins == "*":
    cors_origins = DEFAULT_DEV_ORIGINS

app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_origin_regex=cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1024)

# Khi lên production, nên giới hạn host cụ thể
if getattr(settings, "APP_ENV", "dev") == "prod":
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])  # TODO: thay * bằng domain thật

# ==== Static / Media ====
MEDIA_DIR = Path("media")
AVT_DIR = MEDIA_DIR / "avatars"
UPLOADS_DIR = Path("uploads") / "support"

MEDIA_DIR.mkdir(parents=True, exist_ok=True)
AVT_DIR.mkdir(parents=True, exist_ok=True)
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

app.mount("/media", StaticFiles(directory=str(MEDIA_DIR), html=False), name="media")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ==== Routers ====
app.include_router(health_router, prefix=API_PREFIX)
app.include_router(detect_router, prefix=API_PREFIX)
app.include_router(auth_router, prefix=API_PREFIX)
app.include_router(users_router, prefix=API_PREFIX)
app.include_router(me_router, prefix=API_PREFIX)
app.include_router(support_router, prefix=API_PREFIX)
app.include_router(notifications_router, prefix=API_PREFIX)

app.include_router(users_devices_router, prefix=API_PREFIX)
app.include_router(sensors_router, prefix=API_PREFIX)
app.include_router(device_logs_router, prefix=API_PREFIX)

app.include_router(devices_router, prefix=API_PREFIX)
app.include_router(detection_history_router, prefix=API_PREFIX)
app.include_router(dashboard_router, prefix=API_PREFIX)
app.include_router(support_admin_router, prefix=API_PREFIX)
app.include_router(routes_device_types, prefix=API_PREFIX)
app.include_router(routes_dataset_admin, prefix=API_PREFIX)

# ==== Root & tiện ích ====
@app.get("/")
def root():
    return JSONResponse({"name": getattr(settings, "APP_NAME", "ZestGuard API"), "health": "ok", "docs": "/docs"})

@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    return Response(status_code=204)

@app.get("/.well-known/appspecific/com.chrome.devtools.json", include_in_schema=False)
def chrome_devtools_probe():
    return Response(status_code=204)

# ==== Error handler cho 422 ====
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=HTTP_422_UNPROCESSABLE_ENTITY,
        content={"message": "Payload không hợp lệ", "errors": exc.errors()},
    )
