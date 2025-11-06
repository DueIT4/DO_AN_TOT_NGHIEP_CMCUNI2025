# backend/app/main.py
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from starlette.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import RedirectResponse, JSONResponse, Response
from starlette.staticfiles import StaticFiles
from starlette.status import HTTP_422_UNPROCESSABLE_ENTITY

from app.core.config import settings
import logging

# Khởi tạo logger
logger = logging.getLogger(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

# ==== Routers ====
from app.api.v1.routes_health import router as health_router
from app.api.v1.routes_detect import router as detect_router
from app.api.v1.routes_ingest import router as ingest_router  
from app.api.v1.routes_devices import router as devices_router
from app.api.v1.routes_diseases import router as diseases_router
from app.api.v1.routes_sensors import router as sensors_router
from app.api.v1.routes_notifications import router as notif_router
from app.api.v1.routes_support import router as support_router
from fastapi import FastAPI
from app.api.v1.routes_users import router as users_router
from app.api.v1.routes_auth import router as auth_router



API_PREFIX = getattr(settings, "API_V1", "/api/v1")

tags_metadata = [
    {"name": "Detection", "description": "Upload/Camera → ONNX → LLM → lưu DB."},
    {"name": "Devices", "description": "Quản lý thiết bị, loại thiết bị, logs."},
    {"name": "Diseases", "description": "Danh mục bệnh + guideline điều trị."},
    {"name": "Sensors", "description": "Ghi/đọc dữ liệu cảm biến."},
    {"name": "Notifications", "description": "Thông báo hệ thống cho người dùng."},
    {"name": "Support", "description": "Ticket & hội thoại hỗ trợ khách hàng."},
    {"name": "default", "description": "Health & tiện ích."},
]

# app = FastAPI(
#     title=settings.APP_NAME,
#     openapi_tags=tags_metadata,
# )

# # ==== Middlewares ====
# # CORS: lấy từ config; cho phép regex localhost mọi port khi cần
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=getattr(settings, "CORS_ORIGINS", ["*"]),
#     allow_origin_regex=getattr(settings, "CORS_ORIGIN_REGEX", None),
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

# Cho phép tất cả origin (chạy local dev thì ok)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # hoặc ["http://localhost:55084"] để an toàn hơn
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def read_root():
    return {"message": "CORS ok!"}

# Nén gzip cho response lớn (ảnh base64, markdown dài…)
app.add_middleware(GZipMiddleware, minimum_size=1024)

# (Tuỳ chọn) giới hạn host khi lên prod
if getattr(settings, "APP_ENV", "dev") == "prod":
    app.add_middleware(TrustedHostMiddleware, allowed_hosts=["*"])  # sửa * → domain của bạn

# ==== Static / Media ====
MEDIA_DIR = Path("media")
MEDIA_DIR.mkdir(parents=True, exist_ok=True)
# nơi DetectionService lưu ảnh: media/uploads/...
app.mount("/media", StaticFiles(directory=str(MEDIA_DIR), html=False), name="media")

# ==== Routers ====
app.include_router(health_router,  prefix=API_PREFIX)
app.include_router(detect_router,  prefix=API_PREFIX)
app.include_router(devices_router, prefix=API_PREFIX)
app.include_router(diseases_router, prefix=API_PREFIX)
app.include_router(sensors_router, prefix=API_PREFIX)
app.include_router(notif_router,   prefix=API_PREFIX)
app.include_router(support_router, prefix=API_PREFIX)
app.include_router(ingest_router)  
app.include_router(users_router,   prefix=API_PREFIX)
app.include_router(auth_router, prefix=API_PREFIX)

# ==== Root & tiện ích ====
@app.get("/")
def root():
    """Thông tin cơ bản + link docs."""
    return JSONResponse({
        "name": settings.APP_NAME,
        "health": "ok",
        "docs": f"{API_PREFIX}/docs".replace("//", "/"),  # đề phòng slash lặp
    })

@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    return Response(status_code=204)

@app.get("/.well-known/appspecific/com.chrome.devtools.json", include_in_schema=False)
def chrome_devtools_probe():
    return Response(status_code=204)

# ==== Error handlers đẹp cho 422 ====
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # Trả format gọn gàng cho FE dễ đọc
    return JSONResponse(
        status_code=HTTP_422_UNPROCESSABLE_ENTITY,
        content={
            "message": "Payload không hợp lệ",
            "errors": exc.errors(),
        },
    )
