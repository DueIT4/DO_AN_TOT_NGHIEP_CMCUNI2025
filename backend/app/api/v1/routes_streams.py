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
import time

router = APIRouter()


class StartStreamIn(BaseModel):
    device_id: int


class StopStreamIn(BaseModel):
    device_id: int


class StartTempIn(BaseModel):
    url: str


class StopTempIn(BaseModel):
    key: str


@router.post("/streams/start")
def start_stream(payload: StartStreamIn, db: Session = Depends(get_db)):
    device = db.get(Device, payload.device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Device not found")
    rtsp = device.stream_url or device.gateway_stream_id
    if not rtsp:
        raise HTTPException(status_code=400, detail="Device has no stream URL")

    hls = stream_service.start_stream(payload.device_id, rtsp)
    if hls is None:
        raise HTTPException(status_code=500, detail="ffmpeg not available or failed to start")
    return {"hls_url": hls, "running": True}


@router.post("/streams/stop")
def stop_stream(payload: StopStreamIn):
    ok = stream_service.stop_stream(payload.device_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Stream not running")
    return {"stopped": True}


@router.get("/streams/device/{device_id}")
def get_stream(device_id: int):
    running = stream_service.is_running(device_id)
    return {"running": running, "hls_url": stream_service.hls_url_for(device_id)}


@router.post('/streams/start_temp')
def start_stream_temp(payload: StartTempIn):
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

            time.sleep(interval)
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


@router.post('/streams/stop_temp')
def stop_stream_temp(payload: StopTempIn):
    ok = stream_service.stop_stream_temp(payload.key)
    if not ok:
        raise HTTPException(status_code=404, detail='Stream not running')
    return {"stopped": True}


@router.get('/streams/temp/{key}')
def get_stream_temp(key: str):
    running = stream_service.is_running_temp(key)
    return {"running": running, "hls_url": stream_service.hls_url_for_temp(key)}