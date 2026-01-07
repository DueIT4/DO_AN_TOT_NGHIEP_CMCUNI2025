from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from app.core.config import settings
from app.core.database import get_db
from sqlalchemy.orm import Session
from app.services import stream_service
from app.models.devices import Device
from pydantic import BaseModel
from uuid import uuid4
from typing import Optional
from pathlib import Path
import asyncio

router = APIRouter(prefix="/streams", tags=["streams"])


class StartStreamIn(BaseModel):
    device_id: int


class StopStreamIn(BaseModel):
    device_id: int


class StartTempIn(BaseModel):
    url: str


class StopTempIn(BaseModel):
    key: str


@router.post("/start")
def start_stream(payload: StartStreamIn, db: Session = Depends(get_db)):
    """Start/resume streaming for a device.
    
    ✅ FIX: Stop old stream nếu RTSP URL thay đổi
    """
    import logging
    logger = logging.getLogger(__name__)
    logger.info(f"🎥 ==========================================")
    logger.info(f"🎥 Received start_stream request for device_id={payload.device_id}")
    logger.info(f"🎥 ==========================================")
    
    device = db.get(Device, payload.device_id)
    if not device:
        logger.error(f"❌ Device {payload.device_id} not found in database")
        raise HTTPException(status_code=404, detail="Device not found")
    rtsp = device.stream_url or device.gateway_stream_id
    if not rtsp:
        raise HTTPException(status_code=400, detail="Device has no stream URL")

    # ✅ Backend sẽ tự stop stream cũ nếu RTSP URL khác
    hls = stream_service.start_stream(payload.device_id, rtsp)
    if hls is None:
        raise HTTPException(status_code=500, detail="ffmpeg not available or failed to start")
    return {
        "hls_url": hls,
        "running": True,
        "message": "Stream started or resumed"
    }


@router.post("/stop")
def stop_stream(payload: StopStreamIn):
    ok = stream_service.stop_stream(payload.device_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Stream not running")
    return {"stopped": True}


@router.get("/device/{device_id}")
def get_stream(device_id: int):
    """Get stream status for a device."""
    running = stream_service.is_running(device_id)
    info = stream_service.get_stream_info(device_id)
    
    return {
        "running": running,
        "hls_url": stream_service.hls_url_for(device_id),
        "info": info
    }


@router.get("/active")
def list_active_streams():
    """List all active streams (useful for dashboard)."""
    streams = stream_service.list_active_streams()
    return {
        "active_streams": streams,
        "count": len(streams)
    }


@router.get("/health/{device_id}")
def check_stream_health(device_id: int):
    """Check stream health for a device.
    
    Returns health status including:
    - healthy: bool - overall health status
    - running: bool - if ffmpeg process is running
    - error: str | None - error message if unhealthy
    - hls_exists: bool - if HLS files exist
    - last_update: float | None - seconds since last segment update
    """
    health = stream_service.check_stream_health(device_id)
    return health


@router.post('/start_temp')
async def start_stream_temp(payload: StartTempIn):
    import logging
    logger = logging.getLogger(__name__)

    # create a short random key
    key = uuid4().hex[:12]
    try:
        hls = stream_service.start_stream_temp(key, payload.url)
        if hls is None:
            logger.error('start_stream_temp returned None (ffmpeg not found or failed) for url=%s', payload.url)
            raise HTTPException(status_code=500, detail='ffmpeg not available or failed to start')

        # wait briefly to ensure ffmpeg started and produced the playlist
        #hls_path = Path(hls.lstrip("/"))
        hls_path = Path("media") / hls.replace("/media/", "", 1)
        timeout = 5.0
        interval = 0.2
        waited = 0.0
        while waited < timeout:
            # CHỈ CẦN PLAYLIST XUẤT HIỆN LÀ THÀNH CÔNG
            if hls_path.exists() and hls_path.stat().st_size > 0:
                return {"hls_url": hls, "key": key}

            # Nếu process đã chết sớm thì break để trả lỗi
            if not stream_service.is_running_temp(key):
                break

            await asyncio.sleep(interval)
            waited += interval

        # if we reach here, ffmpeg likely failed early — include tail of ffmpeg.log for debugging
        log_path = Path("media") / "hls" / f"temp-{key}" / "ffmpeg.log"
        log_tail = None
        try:
            if log_path.exists():
                text = log_path.read_text(errors='ignore')
                log_tail = text[-4000:]
        except Exception as e:
            logger.exception('failed to read ffmpeg.log for key=%s: %s', key, e)

        logger.error('ffmpeg failed to start for key=%s url=%s log_exists=%s', key, payload.url, log_path.exists())
        # return structured error with reason and ffmpeg tail when available
        raise HTTPException(status_code=500, detail={
            "message": "ffmpeg failed to start",
            "log_tail": log_tail,
            "key": key,
            "attempted_hls": hls,
        })
    except HTTPException:
        # re-raise HTTP exceptions
        raise
    except Exception as e:
        logger.exception('unexpected error in start_stream_temp: %s', e)
        raise HTTPException(status_code=500, detail={"message": "internal error", "error": str(e)})


@router.post('/stop_temp')
def stop_stream_temp(payload: StopTempIn):
    ok = stream_service.stop_stream_temp(payload.key)
    if not ok:
        raise HTTPException(status_code=404, detail='Stream not running')
    return {"stopped": True}


@router.get('/temp/{key}')
def get_stream_temp(key: str):
    """Get status of temp stream."""
    running = stream_service.is_running_temp(key)
    return {
        "running": running,
        "hls_url": stream_service.hls_url_for_temp(key) if running else None
    }