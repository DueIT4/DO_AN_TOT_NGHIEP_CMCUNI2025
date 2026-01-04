# # app/api/v1/routes_stream.py
# """
# Streaming routes: convert MJPEG → HLS, serve HLS playlists
# """
# import os
# import asyncio
# import subprocess
# from pathlib import Path
# from urllib.parse import unquote

# from fastapi import APIRouter, Query, HTTPException, Response, Request
# from app.services import stream_service
# from fastapi.responses import StreamingResponse

# router = APIRouter(prefix="/stream", tags=["stream"])

# # HLS output directory
# HLS_OUTPUT_DIR = Path("media/hls")
# HLS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


# @router.get("/hls")
# async def hls_stream(
#     request: Request,
#     mjpeg_url: str = Query(...),
# ):
#     """
#     Convert MJPEG stream to HLS and serve.
    
#     Example: GET /stream/hls?mjpeg_url=http://192.168.1.100:4747/video
    
#     Returns: m3u8 playlist URL for video player
#     """
#     mjpeg_url = unquote(mjpeg_url)  # Decode URL-encoded parameter
    
#     # Validate URL
#     if not mjpeg_url.startswith(("http://", "https://")):
#         raise HTTPException(
#             status_code=400,
#             detail="mjpeg_url must be http:// or https://"
#         )
    
#     # ✅ Pre-flight check: Test camera connectivity before starting ffmpeg
#     import requests
#     try:
#         print(f"[HLS] Testing camera connectivity: {mjpeg_url}")
#         test_resp = requests.head(mjpeg_url, timeout=5)
#         print(f"[HLS] Camera test OK: {test_resp.status_code}")
#     except requests.exceptions.RequestException as e:
#         print(f"[HLS] ❌ Camera not accessible: {e}")
#         raise HTTPException(
#             status_code=503,
#             detail={
#                 "message": f"Cannot connect to camera at {mjpeg_url}",
#                 "error": str(e),
#                 "hint": "Please check if camera is running and accessible from backend server"
#             }
#         )
    
#     # Generate unique session ID from hash
#     import hashlib
#     session_id = hashlib.md5(mjpeg_url.encode()).hexdigest()[:8]
#     session_dir = HLS_OUTPUT_DIR / session_id
#     session_dir.mkdir(parents=True, exist_ok=True)
    
#     # ✅ Dùng absolute path để tránh lỗi relative path
#     playlist_file = session_dir / "index.m3u8"
#     output_pattern = str((session_dir / "segment_%03d.ts").absolute())
    
#     # Check if conversion is already running
#     if not playlist_file.exists():
#         # Start ffmpeg conversion asynchronously
#         asyncio.create_task(
#             _convert_mjpeg_to_hls(mjpeg_url, output_pattern, str(playlist_file))
#         )
        
#         # Wait for playlist to be created (with timeout)
#         max_wait = 20  # seconds - tăng để debug
#         wait_interval = 0.5
#         total_waited = 0
        
#         while not playlist_file.exists() and total_waited < max_wait:
#             await asyncio.sleep(wait_interval)
#             total_waited += wait_interval
    
#     if not playlist_file.exists():
#         # Đọc log file để trả error detail như code tham khảo
#         log_file_path = session_dir / "ffmpeg.log"
#         log_tail = None
#         try:
#             if log_file_path.exists():
#                 log_tail = log_file_path.read_text(errors='ignore')[-2000:]
#         except Exception:
#             pass
        
#         raise HTTPException(
#             status_code=503,
#             detail={
#                 "message": "HLS conversion failed to start",
#                 "log_tail": log_tail,
#                 "session_id": session_id,
#                 "hint": "Check if camera URL is accessible and ffmpeg can connect"
#             }
#         )
    
#     # Return HLS playlist URL for frontend to use (dynamic base URL)
#     base = str(request.base_url).rstrip("/")
#     return {
#         "hls_url": f"{base}/api/v1/stream/hls/playlist/{session_id}/index.m3u8",
#         "session_id": session_id,
#         "message": "HLS stream ready"
#     }


# @router.get("/hls/playlist/{session_id}/index.m3u8")
# async def serve_playlist(session_id: str):
#     """Serve HLS playlist file"""
#     playlist_file = HLS_OUTPUT_DIR / session_id / "index.m3u8"
    
#     if not playlist_file.exists():
#         raise HTTPException(status_code=404, detail="Playlist not found")
    
#     with open(playlist_file, "r") as f:
#         content = f.read()
    
#     # Rewrite segment paths to be absolute URLs
#     content = content.replace("segment_", f"/api/v1/stream/hls/segments/{session_id}/segment_")
    
#     return Response(content=content, media_type="application/vnd.apple.mpegurl")


# @router.get("/hls/segments/{session_id}/{filename}")
# async def serve_segment(session_id: str, filename: str):
#     """Serve HLS segment file"""
#     segment_file = HLS_OUTPUT_DIR / session_id / filename
    
#     if not segment_file.exists() or not segment_file.is_file():
#         raise HTTPException(status_code=404, detail="Segment not found")
    
#     with open(segment_file, "rb") as f:
#         content = f.read()
    
#     return Response(content=content, media_type="video/mp2t")


# async def _convert_mjpeg_to_hls(mjpeg_url: str, output_pattern: str, playlist_file: str):
#     """
#     Convert MJPEG stream to HLS using ffmpeg.
#     Runs in background.
#     """
#     import shutil
#     import traceback
    
#     try:
#         # Tìm ffmpeg executable
#         ffmpeg_path = shutil.which("ffmpeg")
#         if not ffmpeg_path:
#             # Thử tìm trong các đường dẫn phổ biến trên Windows
#             common_paths = [
#                 r"D:\ffmpeg\ffmpeg-2025-12-04-git-d6458f6a8b-essentials_build\bin\ffmpeg.exe",
#                 r"C:\ffmpeg\bin\ffmpeg.exe",
#                 r"C:\Program Files\ffmpeg\bin\ffmpeg.exe"
#             ]
#             for path in common_paths:
#                 if os.path.exists(path):
#                     ffmpeg_path = path
#                     break
        
#         if not ffmpeg_path:
#             raise FileNotFoundError("ffmpeg not found in PATH or common locations")
        
#         print(f"[HLS] Using ffmpeg: {ffmpeg_path}")
#         print(f"[HLS] Converting stream URL: {mjpeg_url}")
        
#         # ffmpeg command:
#         # -hide_banner, -loglevel warning: reduce log clutter
#         # -timeout: network timeout in microseconds (30 seconds)
#         # -reconnect 1: auto-reconnect on connection failure
#         # -reconnect_streamed 1: reconnect even for streamed content
#         # -reconnect_delay_max 5: max delay between reconnects
#         # -i: input (let ffmpeg auto-detect format)
#         # -vf: video filter (scale & fps)
#         # -c:v libx264: H.264 video codec
#         # -preset veryfast: encoding speed
#         # -tune zerolatency: minimize delay
#         # -f hls: output format
#         # -hls_time 2: 2 second segments
#         # -hls_list_size 5: keep last 5 segments
#         # -hls_flags delete_segments: delete old segments
#         # -hls_segment_filename: CRITICAL - defines segment naming pattern
        
#         # ✅ Convert all paths to absolute
#         playlist_abs = str(Path(playlist_file).absolute())
#         log_file_path = Path(playlist_file).parent / "ffmpeg.log"
        
#         cmd = [
#             ffmpeg_path,
#             "-hide_banner",
#             "-loglevel", "info",  # Tăng lên để debug
#             "-timeout", "30000000",  # 30 giây timeout
#             "-reconnect", "1",
#             "-reconnect_streamed", "1", 
#             "-reconnect_delay_max", "5",
#             "-i", mjpeg_url,
#             "-vf", "scale=1280:-2,fps=15",
#             "-c:v", "libx264",
#             "-preset", "veryfast",
#             "-tune", "zerolatency",
#             "-f", "hls",
#             "-hls_time", "2",
#             "-hls_list_size", "5",
#             "-hls_flags", "delete_segments",
#             "-hls_segment_filename", output_pattern,
#             "-y",
#             playlist_abs,
#         ]
        
#         print(f"[HLS] Starting ffmpeg process...")
#         print(f"[HLS] Segment pattern: {output_pattern}")
#         print(f"[HLS] Playlist: {playlist_abs}")
        
#         # ✅ FIX: Dùng subprocess.Popen thay vì asyncio.create_subprocess_exec
#         # vì Windows không hỗ trợ async subprocess với event loop mặc định
#         log_file = open(log_file_path, "ab")
        
#         process = subprocess.Popen(
#             cmd,
#             stdout=log_file,
#             stderr=log_file,
#             # Không dùng cwd - dùng absolute paths thay vì relative
#         )
        
#         print(f"[HLS] ✅ ffmpeg process started, PID={process.pid}")
#         print(f"[HLS] Log file: {log_file_path}")
#         print(f"[HLS] Playlist will be at: {playlist_file}")
        
#         # Process sẽ chạy trong background, không cần wait
#         # Frontend sẽ poll để kiểm tra khi nào playlist ready
    
#     except FileNotFoundError as e:
#         print(f"[HLS] ❌ ffmpeg not found: {e}")
#         print(f"[HLS] Please install ffmpeg and add it to PATH")
#         print(f"[HLS] Or place it in: D:\\ffmpeg\\ffmpeg-2025-12-04-git-d6458f6a8b-essential\\bin\\")
#     except Exception as e:
#         print(f"[HLS] ❌ Failed to convert MJPEG to HLS: {e}")
#         print(f"[HLS] Traceback:\n{traceback.format_exc()}")


# # Health check endpoint (used by CameraStreamPlayer)
# @router.get("/health/{device_id}")
# async def stream_health(device_id: int):
#     """
#     Health check for stream.
#     Returns whether the stream is healthy and running.
#     """
#     try:
#         health = stream_service.check_stream_health(device_id)
#         # Bổ sung device_id để tiện debug phía client
#         if isinstance(health, dict):
#             health.setdefault("device_id", device_id)
#         return health
#     except Exception as e:
#         # Trả về unhealthy nếu có lỗi bất ngờ
#         return {
#             "healthy": False,
#             "running": False,
#             "device_id": device_id,
#             "error": f"health check failed: {e}",
#         }
# app/api/v1/routes_stream.py
"""
Streaming routes: convert MJPEG → HLS, serve HLS playlists
Hỗ trợ DroidCam, IP Webcam và camera từ xa với OpenCV + ffmpeg
"""
import os
import asyncio
import subprocess
from pathlib import Path
from urllib.parse import unquote

from fastapi import APIRouter, Query, HTTPException, Response, Request
from app.services import stream_service
from app.services.opencv_hls_service import start_opencv_hls_stream, get_stream_status
from fastapi.responses import StreamingResponse

router = APIRouter(prefix="/stream", tags=["stream"])

# HLS output directory
# HLS output directory - Use system temp dir for Cloud Run compatibility
import tempfile
# On Cloud Run, only /tmp is writable
# We use a subdirectory 'hls' in the system temp directory
TEMP_DIR = Path(tempfile.gettempdir())
HLS_OUTPUT_DIR = TEMP_DIR / "hls"
HLS_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)


@router.get("/test-camera")
async def test_camera_connectivity(mjpeg_url: str = Query(...)):
    """
    Test camera connectivity before starting HLS stream.
    Helps diagnose connection issues.
    
    Returns detailed diagnostic information.
    """
    from urllib.parse import unquote
    import requests
    import socket
    from urllib.parse import urlparse
    
    mjpeg_url = unquote(mjpeg_url)
    
    diagnostic = {
        "url": mjpeg_url,
        "tests": {}
    }
    
    # Parse URL
    try:
        parsed = urlparse(mjpeg_url)
        diagnostic["parsed"] = {
            "scheme": parsed.scheme,
            "host": parsed.hostname,
            "port": parsed.port or 80,
            "path": parsed.path
        }
    except Exception as e:
        diagnostic["tests"]["url_parse"] = {"success": False, "error": str(e)}
        return diagnostic
    
    # Test 1: DNS/Host resolution
    try:
        ip = socket.gethostbyname(parsed.hostname)
        diagnostic["tests"]["dns"] = {"success": True, "ip": ip}
    except Exception as e:
        diagnostic["tests"]["dns"] = {"success": False, "error": str(e)}
        return diagnostic
    
    # Test 2: TCP connection
    try:
        port = parsed.port or 80
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(5)
        result = sock.connect_ex((parsed.hostname, port))
        sock.close()
        
        if result == 0:
            diagnostic["tests"]["tcp"] = {"success": True, "message": f"Port {port} is open"}
        else:
            diagnostic["tests"]["tcp"] = {"success": False, "error": f"Port {port} is closed or filtered"}
            return diagnostic
    except Exception as e:
        diagnostic["tests"]["tcp"] = {"success": False, "error": str(e)}
        return diagnostic
    
    # Test 3: HTTP request
    try:
        response = requests.get(mjpeg_url, timeout=10, stream=True, allow_redirects=True)
        diagnostic["tests"]["http"] = {
            "success": True,
            "status_code": response.status_code,
            "headers": dict(response.headers),
            "content_type": response.headers.get("content-type")
        }
        response.close()
        
        # Check if it's actually an image/video stream
        content_type = response.headers.get("content-type", "").lower()
        if "multipart" in content_type or "image" in content_type or "video" in content_type or "octet-stream" in content_type:
            diagnostic["tests"]["stream_type"] = {
                "success": True,
                "message": "URL appears to be a valid video/image stream"
            }
        else:
            diagnostic["tests"]["stream_type"] = {
                "success": False,
                "warning": f"Content-Type is '{content_type}', may not be a video stream"
            }
    except requests.exceptions.Timeout:
        diagnostic["tests"]["http"] = {"success": False, "error": "Request timeout after 10s"}
        return diagnostic
    except requests.exceptions.ConnectionError as e:
        diagnostic["tests"]["http"] = {"success": False, "error": f"Connection error: {str(e)}"}
        return diagnostic
    except Exception as e:
        diagnostic["tests"]["http"] = {"success": False, "error": str(e)}
        return diagnostic
    
    # Overall status
    all_success = all(
        test.get("success", False) 
        for test in diagnostic["tests"].values()
    )
    
    diagnostic["overall"] = {
        "ready_for_streaming": all_success,
        "recommendation": (
            "✅ Camera is accessible and ready for HLS streaming" 
            if all_success 
            else "❌ Camera has connectivity issues. Check failed tests above."
        )
    }
    
    return diagnostic


@router.get("/hls")
async def hls_stream(
    request: Request,
    mjpeg_url: str = Query(...),
    use_opencv: bool = Query(default=True, description="Use OpenCV approach for better DroidCam/IP Webcam support"),
):
    """
    Convert MJPEG stream to HLS and serve.
    
    ⚠️ NEW: Default sử dụng OpenCV approach cho DroidCam/IP Webcam
    
    Example: GET /stream/hls?mjpeg_url=http://192.168.1.7:4747/video
    
    Parameters:
        - mjpeg_url: URL của camera stream
        - use_opencv: True = OpenCV approach (recommended cho DroidCam)
                      False = ffmpeg direct approach (cho RTSP/standard MJPEG)
    
    Returns: m3u8 playlist URL for video player
    """
    mjpeg_url = unquote(mjpeg_url)  # Decode URL-encoded parameter
    
    # Validate URL
    if not mjpeg_url.startswith(("http://", "https://")):
        raise HTTPException(
            status_code=400,
            detail="mjpeg_url must be http:// or https://"
        )
    
    import hashlib
    session_id = hashlib.md5(mjpeg_url.encode()).hexdigest()[:8]
    
    # ✅ NEW APPROACH: Use OpenCV + ffmpeg pipe (recommended for DroidCam)
    if use_opencv:
        try:
            session_id, output_dir = start_opencv_hls_stream(mjpeg_url)
            playlist_file = output_dir / "index.m3u8"
            
            # Wait for playlist to be created
            max_wait = 15  # OpenCV approach tạo playlist nhanh hơn
            wait_interval = 0.5
            total_waited = 0
            
            import logging
            logger = logging.getLogger(__name__)
            logger.info(f"[HLS-OpenCV] Waiting for playlist (timeout: {max_wait}s)...")
            
            while not playlist_file.exists() and total_waited < max_wait:
                await asyncio.sleep(wait_interval)
                total_waited += wait_interval
                
                if int(total_waited) % 3 == 0:
                    logger.info(f"[HLS-OpenCV] Waited {int(total_waited)}s...")
            
            if not playlist_file.exists():
                # Check stream status for error info
                status = get_stream_status(session_id)
                error_msg = status.get("error") if status else "Unknown error"
                
                raise HTTPException(
                    status_code=503,
                    detail={
                        "message": "Failed to start HLS stream with OpenCV approach",
                        "session_id": session_id,
                        "error": error_msg,
                        "troubleshooting": [
                            "1. Kiểm tra camera có đang chạy không",
                            "2. Kiểm tra URL có accessible không (test trong browser)",
                            "3. Thử với use_opencv=false để dùng ffmpeg direct",
                            "4. Check log file trong media/hls/{session_id}/conversion.log"
                        ]
                    }
                )
            
            # Success!
            base = str(request.base_url).rstrip("/")
            return {
                "hls_url": f"{base}/api/v1/stream/hls/playlist/{session_id}/index.m3u8",
                "session_id": session_id,
                "method": "opencv",
                "message": "HLS stream ready (OpenCV approach)"
            }
            
        except HTTPException:
            raise
        except Exception as e:
            import logging
            logging.getLogger(__name__).error(f"[HLS-OpenCV] Error: {e}", exc_info=True)
            raise HTTPException(
                status_code=500,
                detail=f"Internal error starting OpenCV stream: {str(e)}"
            )
    
    # ✅ FALLBACK: Original ffmpeg direct approach
    else:
        # ⚠️ FIX: Làm pre-flight check optional - nếu fail thì vẫn cho phép ffmpeg thử
        # Vì một số camera MJPEG có thể phản hồi chậm hoặc không trả về status code đúng cách
        import requests
        preflight_ok = False
        preflight_warning = None
        
        try:
            print(f"[HLS] Testing camera connectivity: {mjpeg_url}")
            # Dùng GET với timeout ngắn và stream=True
            # Chỉ đọc header, không đọc body để tránh block stream
            test_resp = requests.get(mjpeg_url, timeout=3, stream=True, allow_redirects=True)
            # Chỉ check status code, không đọc body
            if test_resp.status_code < 500:  # Chấp nhận cả 200, 404, etc. (một số camera trả về 404 nhưng vẫn stream)
                preflight_ok = True
                print(f"[HLS] Camera test OK: {test_resp.status_code}")
            else:
                preflight_warning = f"Camera trả về status code {test_resp.status_code}"
            test_resp.close()
        except requests.exceptions.Timeout:
            preflight_warning = "Camera timeout (có thể camera phản hồi chậm, sẽ để ffmpeg thử)"
            print(f"[HLS] ⚠️ Camera timeout (non-blocking): {mjpeg_url}")
        except requests.exceptions.ConnectionError as e:
            preflight_warning = f"Không thể kết nối (có thể camera chưa sẵn sàng, sẽ để ffmpeg thử): {str(e)}"
            print(f"[HLS] ⚠️ Camera connection error (non-blocking): {e}")
        except requests.exceptions.RequestException as e:
            preflight_warning = f"Lỗi kết nối (sẽ để ffmpeg thử): {str(e)}"
            print(f"[HLS] ⚠️ Camera check failed (non-blocking): {e}")
        
        # ⚠️ KHÔNG raise exception - để ffmpeg tự handle connection
        # Vì một số camera có thể không accessible từ Python requests nhưng ffmpeg có thể kết nối được
        if not preflight_ok:
            print(f"[HLS] ⚠️ Pre-flight check warning: {preflight_warning}")
            print(f"[HLS] ⚠️ Vẫn tiếp tục với ffmpeg - một số camera chỉ accessible từ ffmpeg")
        
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
            # ⚠️ Tăng timeout vì một số camera cần thời gian để ffmpeg kết nối và tạo segments
            max_wait = 30  # seconds - tăng từ 20 lên 30 để cho camera có thời gian khởi động
            wait_interval = 0.5
            total_waited = 0
            
            print(f"[HLS] Đang chờ playlist được tạo (timeout: {max_wait}s)...")
            while not playlist_file.exists() and total_waited < max_wait:
                await asyncio.sleep(wait_interval)
                total_waited += wait_interval
                # Log progress mỗi 5 giây
                if int(total_waited) % 5 == 0:
                    print(f"[HLS] Đã chờ {int(total_waited)}s, vẫn chờ playlist...")
        
        if not playlist_file.exists():
            # Đọc log file để trả error detail như code tham khảo
            log_file_path = session_dir / "ffmpeg.log"
            log_tail = None
            ffmpeg_error = None
            try:
                if log_file_path.exists():
                    log_content = log_file_path.read_text(errors='ignore')
                    log_tail = log_content[-3000:]  # Lấy 3000 ký tự cuối
                    
                    # ⚠️ ENHANCED: Phân tích lỗi chi tiết hơn
                    log_lower = log_tail.lower()
                    
                    # Check common errors
                    if "error number -138" in log_lower or "eagain" in log_lower:
                        ffmpeg_error = (
                            "❌ Camera không phản hồi (Error -138/EAGAIN). "
                            "Kiểm tra:\n"
                            "  1. Camera app (IP Webcam) có đang chạy không?\n"
                            "  2. URL stream có đúng không?\n"
                            "  3. Backend server có kết nối được đến camera không?\n"
                            f"  4. Thử mở URL trong browser: {mjpeg_url}"
                        )
                    elif "ffmpeg not found" in log_lower or "file not found" in log_lower:
                        ffmpeg_error = "❌ ffmpeg không được tìm thấy. Vui lòng cài đặt ffmpeg."
                    elif "connection refused" in log_lower:
                        ffmpeg_error = f"❌ Kết nối bị từ chối. Camera không lắng nghe tại {mjpeg_url}"
                    elif "timeout" in log_lower or "timed out" in log_lower:
                        ffmpeg_error = "❌ Kết nối timeout. Camera phản hồi quá chậm hoặc không khả dụng."
                    elif "403" in log_lower or "forbidden" in log_lower:
                        ffmpeg_error = "❌ Truy cập bị từ chối (403 Forbidden). Cần authentication?"
                    elif "404" in log_lower or "not found" in log_lower:
                        ffmpeg_error = f"❌ URL không tồn tại (404). Kiểm tra lại URL: {mjpeg_url}"
                    elif "401" in log_lower or "unauthorized" in log_lower:
                        ffmpeg_error = "❌ Cần đăng nhập (401 Unauthorized). Camera yêu cầu username/password."
                    elif "end of file" in log_lower or "eof" in log_lower:
                        ffmpeg_error = "❌ Camera đóng kết nối sớm (EOF). Stream không ổn định."
                    else:
                        ffmpeg_error = "❌ Lỗi không xác định. Xem log chi tiết bên dưới."
            except Exception as e:
                print(f"[HLS] Error reading log file: {e}")
            
            error_detail = {
                "message": "❌ Không thể khởi động HLS stream",
                "session_id": session_id,
                "mjpeg_url": mjpeg_url,
                "timeout_seconds": max_wait,
                "troubleshooting": [
                    "1. Kiểm tra camera app (IP Webcam) có đang chạy không",
                    "2. Thử mở URL stream trong browser để test",
                    "3. Kiểm tra firewall/network giữa backend và camera",
                    "4. Đảm bảo URL stream chính xác (không có typo)",
                    "5. Nếu cần authentication, thêm vào URL: http://user:pass@ip:port/video"
                ]
            }
            
            if ffmpeg_error:
                error_detail["ffmpeg_error"] = ffmpeg_error
            
            if log_tail:
                error_detail["log_tail"] = log_tail
            
            print(f"[HLS] ❌ Failed to create playlist after {max_wait}s")
            print(f"[HLS] Session ID: {session_id}")
            print(f"[HLS] Log file: {log_file_path}")
            print(f"[HLS] Pre-flight warning: {preflight_warning}")
            
            # Thêm preflight warning vào error detail nếu có
            if preflight_warning:
                error_detail["preflight_warning"] = preflight_warning
            
            raise HTTPException(
                status_code=503,
                detail=error_detail
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
        
        # Nếu không tìm thấy trong PATH (thường xảy ra trên Windows dev env)
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
        # -timeout: network timeout in microseconds (30 seconds)
        # -reconnect 1: auto-reconnect on connection failure
        # -reconnect_streamed 1: reconnect even for streamed content
        # -reconnect_delay_max 5: max delay between reconnects
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
        
        # ✅ ENHANCED: Tối ưu cho DroidCam/IP Webcam multipart streams
        # DroidCam trả về multipart/x-mixed-replace;boundary=--dcmjpeg
        # KHÔNG dùng -f mjpeg vì sẽ fail với "No JPEG data found"
        cmd = [
            ffmpeg_path,
            "-hide_banner",
            "-loglevel", "info",
            # ⚠️ CRITICAL: KHÔNG force format, để ffmpeg auto-detect multipart stream
            # "-f", "mjpeg",  # ❌ BỎ DÒNG NÀY - gây lỗi với DroidCam
            "-analyzeduration", "10000000",  # 10 giây - tăng lên để parse multipart
            "-probesize", "10000000",  # 10MB probe size
            # Timeout và retry
            "-timeout", "120000000",  # 120 giây
            "-reconnect", "1",
            "-reconnect_streamed", "1",
            "-reconnect_delay_max", "10",
            "-reconnect_at_eof", "1",
            # ⚠️ User-Agent để một số camera không block
            "-user_agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            # Input - để ffmpeg auto-detect format
            "-i", mjpeg_url,
            # Video processing - tối ưu cho realtime
            "-vf", "scale=1280:-2,fps=15",
            "-c:v", "libx264",
            "-preset", "ultrafast",  # ultrafast cho latency thấp
            "-tune", "zerolatency",
            "-g", "30",  # Keyframe mỗi 30 frames
            "-sc_threshold", "0",  # Disable scene change detection
            "-pix_fmt", "yuv420p",  # ⚠️ Đảm bảo compatible pixel format
            # HLS output
            "-f", "hls",
            "-hls_time", "2",
            "-hls_list_size", "5",
            "-hls_flags", "delete_segments+append_list",
            "-hls_segment_type", "mpegts",
            "-hls_segment_filename", output_pattern,
            "-start_number", "0",
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