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

# Import models để SQLAlchemy map đầy đủ (không dùng trực tiếp)
from app.models import user, role, auth_account  # noqa: F401

# ==== Logging ====
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")

# ==== Routers ====
from app.api.v1.routes_health import router as health_router
from app.api.v1.routes_detect import router as detect_router
from app.api.v1.routes_auth import router as auth_router
from app.api.v1.routes_users import router as users_router
from app.api.v1.routes_me import router as me_router
from app.api.v1.routes_support import router as support_router
from app.api.v1.routes_notifications import router as notifications_router

# Nếu bạn có thêm các router dưới đây thì bỏ comment import & include ở cuối:
# from app.api.v1.routes_devices import router as devices_router
# from app.api.v1.routes_diseases import router as diseases_router
# from app.api.v1.routes_sensors import router as sensors_router
# from app.api.v1.routes_ingest import router as ingest_router

# Bắt buộc gọi trước khi tạo app nếu có relationships phức tạp
configure_mappers()

API_PREFIX = getattr(settings, "API_V1", "/api/v1")

tags_metadata = [
    {"name": "Detection", "description": "Upload/Camera → ONNX → LLM → lưu DB."},
    {"name": "Notifications", "description": "Thông báo hệ thống cho người dùng."},
    {"name": "Support", "description": "Ticket & hội thoại hỗ trợ khách hàng."},
    {"name": "Users", "description": "Quản lý người dùng & hồ sơ cá nhân."},
    {"name": "default", "description": "Health & tiện ích."},
]

app = FastAPI(
    title=settings.APP_NAME,
    docs_url="/docs",            # Truy cập Swagger tại /docs
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    openapi_tags=tags_metadata,
)

# ==== Middlewares ====
app.add_middleware(
    CORSMiddleware,
    allow_origins=getattr(settings, "CORS_ORIGINS", ["*"]),
    allow_origin_regex=getattr(settings, "CORS_ORIGIN_REGEX", None),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.add_middleware(GZipMiddleware, minimum_size=1024)

# Khi lên production, nên giới hạn host cụ thể
if getattr(settings, "APP_ENV", "dev") == "prod":
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])  # thay * bằng domain của bạn

# ==== Static / Media ====
MEDIA_DIR = Path("media")
AVT_DIR = MEDIA_DIR / "avatars"
UPLOADS_DIR = Path("uploads") / "support"

MEDIA_DIR.mkdir(parents=True, exist_ok=True)
AVT_DIR.mkdir(parents=True, exist_ok=True)
UPLOADS_DIR.mkdir(parents=True, exist_ok=True)

# Truy cập file tĩnh
app.mount("/media", StaticFiles(directory=str(MEDIA_DIR), html=False), name="media")
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# ==== Routers ====
app.include_router(health_router,        prefix=API_PREFIX)
app.include_router(detect_router,        prefix=API_PREFIX)
app.include_router(auth_router,          prefix=API_PREFIX)
app.include_router(users_router,         prefix=API_PREFIX)
app.include_router(me_router,            prefix=API_PREFIX)
app.include_router(support_router,       prefix=API_PREFIX)
app.include_router(notifications_router, prefix=API_PREFIX)

# Nếu có các router mở rộng, bỏ comment để kích hoạt:
# app.include_router(devices_router,      prefix=API_PREFIX)
# app.include_router(diseases_router,     prefix=API_PREFIX)
# app.include_router(sensors_router,      prefix=API_PREFIX)
# app.include_router(ingest_router)  # tuỳ bạn muốn prefix hay không

# ==== Root & tiện ích ====
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

# ==== Error handler cho 422 ====
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=HTTP_422_UNPROCESSABLE_ENTITY,
        content={"message": "Payload không hợp lệ", "errors": exc.errors()},
    )
