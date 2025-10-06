from fastapi import FastAPI
from fastapi.responses import RedirectResponse, JSONResponse, Response
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.api.v1.routes_health import router as health_router
from app.api.v1.routes_detect import router as detect_router

app = FastAPI(title=settings.APP_NAME)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_origin_regex=getattr(settings, 'CORS_ORIGIN_REGEX', None),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix=f"{settings.API_V1}")
app.include_router(detect_router, prefix=f"{settings.API_V1}")

@app.get("/")
def root():
    # Return a minimal JSON; alternatively redirect to docs
    return JSONResponse({"name": settings.APP_NAME, "health": "ok", "docs": f"{settings.API_V1}/docs"})

@app.get("/favicon.ico", include_in_schema=False)
def favicon():
    # Avoid 404 noise for browser favicon requests
    return Response(status_code=204)

@app.get("/.well-known/appspecific/com.chrome.devtools.json", include_in_schema=False)
def chrome_devtools_probe():
    # Silence Chrome DevTools probe 404s
    return Response(status_code=204)
