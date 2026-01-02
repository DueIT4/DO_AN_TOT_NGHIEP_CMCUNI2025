"""
Streaming routes: convert MJPEG → HLS, serve HLS playlists
Tối ưu hóa cho Google Cloud Run (Stateless & Ephemeral Storage)
"""
import os
import asyncio
import subprocess
import hashlib
import shutil
import traceback
from pathlib import Path
from urllib.parse import unquote
from typing import Optional

from fastapi import APIRouter, Query, HTTPException, Response, Request
from fastapi.responses import StreamingResponse
from app.services import stream_service

router = APIRouter(prefix="/stream", tags=["stream"])

# ✅ TRÊN CLOUD RUN: Chỉ thư mục /tmp là có quyền ghi.
# Chúng ta sử dụng /tmp/hls để chứa các phân đoạn video ngắn hạn.
HLS_OUTPUT_DIR = Path("/tmp/hls")
HLS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


@router.get("/hls")
async def hls_stream(
    request: Request,
    mjpeg_url: str = Query(...),
):
    """
    Convert MJPEG stream to HLS and serve.
    Example: GET /stream/hls?mjpeg_url=http://camera-ip:port/video
    """
    mjpeg_url = unquote(mjpeg_url)
    
    if not mjpeg_url.startswith(("http://", "https://")):
        raise HTTPException(
            status_code=400,
            detail="mjpeg_url must be http:// or https://"
        )
    
    # Generate unique session ID
    session_id = hashlib.md5(mjpeg_url.encode()).hexdigest()[:8]
    session_dir = HLS_OUTPUT_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    
    playlist_file = session_dir / "index.m3u8"
    output_pattern = str((session_dir / "segment_%03d.ts").absolute())
    
    # Kiểm tra nếu tiến trình ffmpeg cho session này chưa chạy
    # Lưu ý: Trên Cloud Run, nếu container bị tắt, session này sẽ biến mất.
    if not playlist_file.exists():
        asyncio.create_task(
            _convert_mjpeg_to_hls(mjpeg_url, output_pattern, str(playlist_file))
        )
        
        # Đợi playlist được tạo ra ban đầu
        max_wait = 15 
        wait_interval = 0.5
        total_waited = 0
        
        while not playlist_file.exists() and total_waited < max_wait:
            await asyncio.sleep(wait_interval)
            total_waited += wait_interval
    
    if not playlist_file.exists():
        log_file_path = session_dir / "ffmpeg.log"
        log_tail = None
        try:
            if log_file_path.exists():
                log_tail = log_file_path.read_text(errors='ignore')[-1000:]
        except Exception: pass
        
        raise HTTPException(
            status_code=503,
            detail={
                "message": "HLS conversion failed to start on Cloud Run",
                "log_tail": log_tail,
                "hint": "Ensure ffmpeg is installed in Dockerfile and camera URL is reachable"
            }
        )
    
    base = str(request.base_url).rstrip("/")
    return {
        "hls_url": f"{base}/api/v1/stream/hls/playlist/{session_id}/index.m3u8",
        "session_id": session_id,
        "message": "HLS stream ready (Cloud mode)"
    }


@router.get("/hls/playlist/{session_id}/index.m3u8")
async def serve_playlist(session_id: str):
    """Serve HLS playlist file từ bộ nhớ tạm /tmp"""
    playlist_file = HLS_OUTPUT_DIR / session_id / "index.m3u8"
    
    if not playlist_file.exists():
        raise HTTPException(status_code=404, detail="Stream session expired or not found")
    
    with open(playlist_file, "r") as f:
        content = f.read()
    
    # Rewrite paths để trỏ về endpoint segments của API
    content = content.replace("segment_", f"/api/v1/stream/hls/segments/{session_id}/segment_")
    
    return Response(content=content, media_type="application/vnd.apple.mpegurl")


@router.get("/hls/segments/{session_id}/{filename}")
async def serve_segment(session_id: str, filename: str):
    """Serve HLS segment file (.ts)"""
    segment_file = HLS_OUTPUT_DIR / session_id / filename
    
    if not segment_file.exists():
        raise HTTPException(status_code=404, detail="Segment expired")
    
    return StreamingResponse(open(segment_file, "rb"), media_type="video/mp2t")


async def _convert_mjpeg_to_hls(mjpeg_url: str, output_pattern: str, playlist_file: str):
    """
    Chuyển đổi MJPEG sang HLS bằng ffmpeg.
    Tối ưu cho Docker (Linux).
    """
    try:
        # ✅ TRÊN DOCKER/LINUX: ffmpeg thường nằm sẵn trong PATH
        ffmpeg_path = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"
        
        playlist_abs = str(Path(playlist_file).absolute())
        log_file_path = Path(playlist_file).parent / "ffmpeg.log"
        
        # Lệnh FFmpeg tối ưu cho Cloud Run (giảm CPU, không lưu quá nhiều segment)
        cmd = [
            ffmpeg_path,
            "-hide_banner",
            "-loglevel", "warning",
            "-i", mjpeg_url,
            "-vf", "scale=854:-2,fps=10", # Giảm độ phân giải xuống 480p để tiết kiệm CPU trên Cloud Run
            "-c:v", "libx264",
            "-preset", "ultrafast",       # Nhanh nhất có thể để giảm độ trễ
            "-tune", "zerolatency",
            "-g", "20",                    # Keyframe interval
            "-f", "hls",
            "-hls_time", "2",              # Mỗi segment 2 giây
            "-hls_list_size", "3",         # Chỉ giữ 3 segment gần nhất (tiết kiệm RAM/Disk)
            "-hls_flags", "delete_segments+append_list",
            "-hls_segment_filename", output_pattern,
            "-y",
            playlist_abs,
        ]
        
        log_file = open(log_file_path, "ab")
        
        # Sử dụng subprocess.Popen để chạy ngầm
        process = subprocess.Popen(
            cmd,
            stdout=log_file,
            stderr=log_file,
            start_new_session=True # Đảm bảo process không bị chết khi request kết thúc
        )
        
        print(f"[HLS-Cloud] ffmpeg started PID={process.pid} for {mjpeg_url}")
        
    except Exception as e:
        print(f"[HLS-Cloud] Error: {e}")
        print(traceback.format_exc())


@router.get("/health/{device_id}")
async def stream_health(device_id: int):
    try:
        health = stream_service.check_stream_health(device_id)
        if isinstance(health, dict):
            health.setdefault("device_id", device_id)
        return health
    except Exception as e:
        return {
            "healthy": False,
            "running": False,
            "device_id": device_id,
            "error": str(e),
        }