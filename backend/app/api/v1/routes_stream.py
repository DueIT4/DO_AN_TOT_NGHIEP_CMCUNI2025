# app/api/v1/routes_stream.py
"""
Streaming routes: convert MJPEG → HLS, serve HLS playlists
"""
import os
import asyncio
import subprocess
from pathlib import Path
from urllib.parse import unquote

from fastapi import APIRouter, Query, HTTPException, Response, Request
from app.services import stream_service
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/stream", tags=["stream"])

# HLS output directory
HLS_OUTPUT_DIR = Path("media/hls")
HLS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


@router.get("/hls")
async def hls_stream(
    request: Request,
    mjpeg_url: str = Query(...),
):
    """
    Convert MJPEG stream to HLS and serve.
    
    Example: GET /stream/hls?mjpeg_url=http://192.168.1.100:4747/video
    
    Returns: m3u8 playlist URL for video player
    """
    mjpeg_url = unquote(mjpeg_url)  # Decode URL-encoded parameter
    
    # Validate URL
    if not mjpeg_url.startswith(("http://", "https://")):
        raise HTTPException(
            status_code=400,
            detail="mjpeg_url must be http:// or https://"
        )
    
    # Generate unique session ID from hash
    import hashlib
    session_id = hashlib.md5(mjpeg_url.encode()).hexdigest()[:8]
    session_dir = HLS_OUTPUT_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    
    # ✅ Dùng absolute path để tránh lỗi relative path
    playlist_file = session_dir / "index.m3u8"
    output_pattern = str((session_dir / "segment_%03d.ts").absolute())
    
    # Check if conversion is already running
    if not playlist_file.exists():
        # Start ffmpeg conversion asynchronously
        asyncio.create_task(
            _convert_mjpeg_to_hls(mjpeg_url, output_pattern, str(playlist_file))
        )
        
        # Wait for playlist to be created (with timeout)
        max_wait = 20  # seconds - tăng để debug
        wait_interval = 0.5
        total_waited = 0
        
        while not playlist_file.exists() and total_waited < max_wait:
            await asyncio.sleep(wait_interval)
            total_waited += wait_interval
    
    if not playlist_file.exists():
        # Đọc log file để trả error detail như code tham khảo
        log_file_path = session_dir / "ffmpeg.log"
        log_tail = None
        try:
            if log_file_path.exists():
                log_tail = log_file_path.read_text(errors='ignore')[-2000:]
        except Exception:
            pass
        
        raise HTTPException(
            status_code=503,
            detail={
                "message": "HLS conversion failed to start",
                "log_tail": log_tail,
                "session_id": session_id,
                "hint": "Check if camera URL is accessible and ffmpeg can connect"
            }
        )
    
    # Return HLS playlist URL for frontend to use (dynamic base URL)
    base = str(request.base_url).rstrip("/")
    return {
        "hls_url": f"{base}/api/v1/stream/hls/playlist/{session_id}/index.m3u8",
        "session_id": session_id,
        "message": "HLS stream ready"
    }


@router.get("/hls/playlist/{session_id}/index.m3u8")
async def serve_playlist(session_id: str):
    """Serve HLS playlist file"""
    playlist_file = HLS_OUTPUT_DIR / session_id / "index.m3u8"
    
    if not playlist_file.exists():
        raise HTTPException(status_code=404, detail="Playlist not found")
    
    with open(playlist_file, "r") as f:
        content = f.read()
    
    # Rewrite segment paths to be absolute URLs
    content = content.replace("segment_", f"/api/v1/stream/hls/segments/{session_id}/segment_")
    
    return Response(content=content, media_type="application/vnd.apple.mpegurl")


@router.get("/hls/segments/{session_id}/{filename}")
async def serve_segment(session_id: str, filename: str):
    """Serve HLS segment file"""
    segment_file = HLS_OUTPUT_DIR / session_id / filename
    
    if not segment_file.exists() or not segment_file.is_file():
        raise HTTPException(status_code=404, detail="Segment not found")
    
    with open(segment_file, "rb") as f:
        content = f.read()
    
    return Response(content=content, media_type="video/mp2t")


async def _convert_mjpeg_to_hls(mjpeg_url: str, output_pattern: str, playlist_file: str):
    """
    Convert MJPEG stream to HLS using ffmpeg.
    Runs in background.
    """
    import shutil
    import traceback
    
    try:
        # Tìm ffmpeg executable
        ffmpeg_path = shutil.which("ffmpeg")
        if not ffmpeg_path:
            # Thử tìm trong các đường dẫn phổ biến trên Windows
            common_paths = [
                r"D:\ffmpeg\ffmpeg-2025-12-04-git-d6458f6a8b-essentials_build\bin\ffmpeg.exe",
                r"C:\ffmpeg\bin\ffmpeg.exe",
                r"C:\Program Files\ffmpeg\bin\ffmpeg.exe"
            ]
            for path in common_paths:
                if os.path.exists(path):
                    ffmpeg_path = path
                    break
        
        if not ffmpeg_path:
            raise FileNotFoundError("ffmpeg not found in PATH or common locations")
        
        print(f"[HLS] Using ffmpeg: {ffmpeg_path}")
        print(f"[HLS] Converting stream URL: {mjpeg_url}")
        
        # ffmpeg command:
        # -hide_banner, -loglevel warning: reduce log clutter
        # -i: input (let ffmpeg auto-detect format)
        # -vf: video filter (scale & fps)
        # -c:v libx264: H.264 video codec
        # -preset veryfast: encoding speed
        # -tune zerolatency: minimize delay
        # -f hls: output format
        # -hls_time 2: 2 second segments
        # -hls_list_size 5: keep last 5 segments
        # -hls_flags delete_segments: delete old segments
        # -hls_segment_filename: CRITICAL - defines segment naming pattern
        
        # ✅ Convert all paths to absolute
        playlist_abs = str(Path(playlist_file).absolute())
        log_file_path = Path(playlist_file).parent / "ffmpeg.log"
        
        cmd = [
            ffmpeg_path,
            "-hide_banner",
            "-loglevel", "warning",
            "-i", mjpeg_url,
            "-vf", "scale=1280:-2,fps=15",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-tune", "zerolatency",
            "-f", "hls",
            "-hls_time", "2",
            "-hls_list_size", "5",
            "-hls_flags", "delete_segments",
            "-hls_segment_filename", output_pattern,
            "-y",
            playlist_abs,
        ]
        
        print(f"[HLS] Starting ffmpeg process...")
        print(f"[HLS] Segment pattern: {output_pattern}")
        print(f"[HLS] Playlist: {playlist_abs}")
        
        # ✅ FIX: Dùng subprocess.Popen thay vì asyncio.create_subprocess_exec
        # vì Windows không hỗ trợ async subprocess với event loop mặc định
        log_file = open(log_file_path, "ab")
        
        process = subprocess.Popen(
            cmd,
            stdout=log_file,
            stderr=log_file,
            # Không dùng cwd - dùng absolute paths thay vì relative
        )
        
        print(f"[HLS] ✅ ffmpeg process started, PID={process.pid}")
        print(f"[HLS] Log file: {log_file_path}")
        print(f"[HLS] Playlist will be at: {playlist_file}")
        
        # Process sẽ chạy trong background, không cần wait
        # Frontend sẽ poll để kiểm tra khi nào playlist ready
    
    except FileNotFoundError as e:
        print(f"[HLS] ❌ ffmpeg not found: {e}")
        print(f"[HLS] Please install ffmpeg and add it to PATH")
        print(f"[HLS] Or place it in: D:\\ffmpeg\\ffmpeg-2025-12-04-git-d6458f6a8b-essential\\bin\\")
    except Exception as e:
        print(f"[HLS] ❌ Failed to convert MJPEG to HLS: {e}")
        print(f"[HLS] Traceback:\n{traceback.format_exc()}")


# Health check endpoint (used by CameraStreamPlayer)
@router.get("/health/{device_id}")
async def stream_health(device_id: int):
    """
    Health check for stream.
    Returns whether the stream is healthy and running.
    """
    try:
        health = stream_service.check_stream_health(device_id)
        # Bổ sung device_id để tiện debug phía client
        if isinstance(health, dict):
            health.setdefault("device_id", device_id)
        return health
    except Exception as e:
        # Trả về unhealthy nếu có lỗi bất ngờ
        return {
            "healthy": False,
            "running": False,
            "device_id": device_id,
            "error": f"health check failed: {e}",
        }