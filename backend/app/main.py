# app/main.py
from pathlib import Path
import logging
import os  # ✅ Thêm mới để đọc biến môi trường

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from fastapi.exceptions import RequestValidationError
from starlette.middleware.trustedhost import TrustedHostMiddleware
from starlette.staticfiles import StaticFiles
from starlette.status import HTTP_422_UNPROCESSABLE_ENTITY

from sqlalchemy.orm import configure_mappers
from dotenv import load_dotenv  # ✅ Thêm mới để nạp file .env

from app.core.config import settings

# ==== 1. Load Biến môi trường (.env) ====
# Phải gọi load_dotenv TRƯỚC khi các service khác (như Cloudinary) khởi tạo
load_dotenv() 

# Import models để SQLAlchemy map đầy đủ
import app.models  # noqa: F401
from app.models import user, role, auth_account  # noqa: F401

# ==== 2. Logging Configuration ====
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# Kiểm tra log xem đã nhận được Cloudinary URL hoặc API Key chưa
c_url = os.getenv("CLOUDINARY_URL")
api_key = os.getenv("CLOUDINARY_API_KEY")
if c_url:
    logger.info(f"🚀 Cloudinary Configured via URL: {c_url[:20]}...")
elif api_key:
    logger.info(f"🚀 Cloudinary Configured via API Key: {api_key[:5]}*****")
else:
    logger.warning("⚠️ CLOUDINARY configuration missing in .env - Uploads will fail!")

# Bắt buộc gọi trước khi tạo app nếu có relationships phức tạp
# configure_mappers()

# ==== 3. Import Routers ====
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
from app.api.v1.routes_reports import router as routes_reports
from app.api.v1.routes_weather import router as weather_router
from app.api.v1.routes_news import router as news_router
from app.api.v1.routes_chatbot import router as chatbot_router
from app.api.v1.routes_stream import router as stream_router

API_PREFIX = getattr(settings, "API_V1", "/api/v1")

tags_metadata = [
    {"name": "Detection", "description": "Upload/Camera → ONNX → LLM → Cloudinary → lưu DB."},
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

# ==== 4. Middleware log requests (Debug Terminal) ====
@app.middleware("http")
async def log_requests(request: Request, call_next):
    logger.info(f"Incoming: {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(f"Outgoing: {request.method} {request.url.path} -> {response.status_code}")
    return response

# Trong file main.py của Backend
origins = [
    "http://localhost:3000",
    "https://ai-plant-health-65293.web.app", # Link Firebase của bạn
    "https://ai-plant-health-65293.firebaseapp.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1024)

if getattr(settings, "APP_ENV", "dev") == "prod":
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])

import tempfile

# ==== 6. Static / Media / HLS Directories ====
MEDIA_DIR = Path("media")
AVT_DIR = MEDIA_DIR / "avatars"
UPLOADS_DIR = Path("uploads") / "support"

# ✅ Use system temp dir (compatible with Cloud Run & Windows)
TEMP_DIR = Path(tempfile.gettempdir())
HLS_TMP_DIR = TEMP_DIR / "hls"

for d in [MEDIA_DIR, AVT_DIR, UPLOADS_DIR, HLS_TMP_DIR]:
    d.mkdir(parents=True, exist_ok=True)

app.mount("/media", StaticFiles(directory=str(MEDIA_DIR), html=False), name="media")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
# ✅ Mount temp directory for HLS
app.mount("/hls_static", StaticFiles(directory=str(HLS_TMP_DIR)), name="hls_static")

# ==== 7. Routers Registration ====
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
app.include_router(routes_reports, prefix=API_PREFIX)
app.include_router(weather_router, prefix=API_PREFIX)
app.include_router(news_router, prefix=API_PREFIX)
app.include_router(chatbot_router, prefix=API_PREFIX)
app.include_router(stream_router, prefix=API_PREFIX)

# ==== 8. Root & Tiện ích ====
@app.get("/")
def root():
    return JSONResponse({"name": getattr(settings, "APP_NAME", "ZestGuard API"), "health": "ok", "docs": "/docs"})

# ✅ Đã sửa: Bọc an toàn Scheduler để không làm sập server nếu thiếu file
@app.on_event("startup")
async def startup_event():
    logger.info(" Server startup: System is ready")
    try:
        from app.services.scheduler_service import start_scheduler
        start_scheduler()
        logger.info(" Scheduler khởi động thành công")
    except Exception as e:
        logger.warning(f" Tạm thời bỏ qua Scheduler: {e}")

@app.on_event("shutdown")
async def shutdown_event():
    try:
        from app.services.scheduler_service import stop_scheduler
        stop_scheduler()
        logger.info(" Scheduler dừng thành công")
    except Exception as e:
        pass

@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    return Response(status_code=204)

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=HTTP_422_UNPROCESSABLE_ENTITY,
        content={"message": "Payload không hợp lệ", "errors": exc.errors()},
    )