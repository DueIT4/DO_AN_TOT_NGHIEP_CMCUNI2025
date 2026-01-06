import subprocess
import os
import threading
from typing import Optional
from pathlib import Path
import shutil
import logging
import time
import cv2  # OpenCV

from app.core.database import SessionLocal
from app.services import detect_service, inference_service

logger = logging.getLogger(__name__)

_procs = {}  # {device_id: {'proc': Popen, 'rtsp_url': str, 'log_file': file_obj}}
_temp_procs = {}  # {key: {'proc': Popen, 'rtsp_url': str, 'log_file': file_obj}}
_capture_threads = {} # {device_id: {'stop_event': Event, 'thread': Thread}}
_lock = threading.Lock()

HLS_ROOT = Path("media/hls")
HLS_ROOT.mkdir(parents=True, exist_ok=True)


def _hls_dir(device_id: int) -> Path:
    d = HLS_ROOT / str(device_id)
    d.mkdir(parents=True, exist_ok=True)
    return d


def hls_url_for(device_id: int) -> str:
    return f"/media/hls/{device_id}/index.m3u8"


def _hls_temp_dir(key: str) -> Path:
    d = HLS_ROOT / f"temp-{key}"
    d.mkdir(parents=True, exist_ok=True)
    return d


def hls_url_for_temp(key: str) -> str:
    return f"/media/hls/temp-{key}/index.m3u8"


# =========================================================================
# ✅ BACKGROUND AUTO-CAPTURE LOOP
# =========================================================================
def _capture_loop(device_id: int, rtsp_url: str, stop_event: threading.Event):
    """
    Chạy ngầm: cứ 60s capture 1 frame và chạy detection + lưu lịch sử.
    """
    logger.info(f"[Capture] Started auto-capture loop for device {device_id}")
    
    last_capture_time = 0
    capture_interval = 60.0 # seconds
    
    while not stop_event.is_set():
        try:
            current_time = time.time()
            
            # Chỉ capture nếu đã qua interval
            if current_time - last_capture_time < capture_interval:
                time.sleep(1) # Sleep ngắn để check stop_event
                continue
                
            # Khởi tạo/Reconnect OpenCV -> REPLACED WITH FFMPEG SINGLE FRAME GRAB
            # cv2.VideoCapture often fails with HTTP/Ngrok headers.
            # We use ffmpeg to grab 1 frame directly to memory.
            
            cmd = [
                "ffmpeg", 
                "-headers", "ngrok-skip-browser-warning: 69420\r\nUser-Agent: FFMPEG",
                "-y",
                "-i", rtsp_url,
                "-vframes", "1",
                "-f", "image2",
                "-pipe:1" # Output to stdout
            ]
            
            try:
                # Run ffmpeg to grab 1 frame
                # Timeout 10s to prevent hanging
                raw_bytes = subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=10)
                
                if not raw_bytes:
                    logger.warning("[Capture] FFmpeg returned empty bytes")
                    time.sleep(5)
                    continue
                    
                # Success grab
                last_capture_time = current_time
                
                # Check valid JPEG header (FF D8)
                if not raw_bytes.startswith(b'\xff\xd8'):
                     logger.warning("[Capture] Invalid JPEG data received")
                     continue

                # Chạy Detection (Logic giống routes_detect)
                # 1. Predict
                detector = inference_service.detector
                if not detector:
                    logger.error("[Capture] Detector model not loaded")
                    continue
                    
                yolo_result = detector.predict_bytes(raw_bytes=raw_bytes, conf=0.5, iou=0.5)
                
                # 2. Save to DB
                db = SessionLocal()
                try:
                    # Query device để lấy user_id
                    from app.models.devices import Device
                    device = db.query(Device).filter(Device.device_id == device_id).first()
                    if not device or not device.user_id:
                        logger.warning(f"[Capture] Device {device_id} has no owner, skipping save.")
                    else:
                        filename = f"autocap_{device_id}_{int(current_time)}.jpg"
                        
                        # upload_image_to_cloudinary is handled inside save_detection_result (we fixed it to not crash)
                        detect_service.save_detection_result(
                            db=db,
                            image_url=None, 
                            filename=filename,
                            yolo_result=yolo_result,
                            user_id=device.user_id,
                            device_id=device_id,
                            raw=raw_bytes,
                            create_alert=True 
                        )
                        logger.info(f"[Capture] Saved history for device {device_id}")
                        
                except Exception as e:
                    logger.error(f"[Capture] Error saving result: {e}")
                finally:
                    db.close()

            except subprocess.TimeoutExpired:
                logger.warning("[Capture] FFmpeg timed out grabbing frame")
                time.sleep(2)
            except Exception as e:
                 # logger.error(f"[Capture] FFmpeg error: {e}") 
                 # Reduce log noise
                 time.sleep(5)

        except Exception as e:
            logger.error(f"[Capture] Loop error: {e}")
            time.sleep(5)
    logger.info(f"[Capture] Stopped loop for device {device_id}")


def start_stream(device_id: int, rtsp_url: str) -> Optional[str]:
    """Start ffmpeg to transcode RTSP -> HLS for the given device.
    Returns HLS index path (relative) or None on failure.
    
    ✅ FIX: 
    - Cleanup old process if RTSP URL changed
    - Store log_file handle để close properly
    """
    with _lock:
        if device_id in _procs:
            proc_info = _procs[device_id]
            old_rtsp = proc_info.get('rtsp_url')
            
            # ✅ Nếu RTSP URL thay đổi → stop stream cũ, start mới
            if old_rtsp != rtsp_url:
                logger.info(f"[Stream] Device {device_id}: RTSP URL changed, stopping old stream")
                _cleanup_proc(device_id)
            else:
                # RTSP URL không đổi, check process
                proc = proc_info['proc']
                if proc.poll() is not None:
                    logger.info(f"[Stream] Device {device_id}: Old process died, restarting...")
                    _cleanup_proc(device_id)
                else:
                    # Process đang chạy, RTSP URL không đổi → return HLS hiện tại
                    logger.debug(f"[Stream] Device {device_id}: Stream already running")
                    return hls_url_for(device_id)

        out_dir = _hls_dir(device_id)
        index_path = out_dir / "index.m3u8"

        # ffmpeg command: re-encode to H.264 + AAC and produce short HLS segments
        cmd = ["ffmpeg", "-y"]
        url_lower = rtsp_url.lower()
        if url_lower.startswith('rtsp://'):
            cmd += ["-rtsp_transport", "tcp"]
        else:
            # DroidCam / HTTP MJPEG streams need explicit demuxer AND headers for Ngrok
            cmd += [
                "-headers", "ngrok-skip-browser-warning: 69420\r\nUser-Agent: FFMPEG", 
                "-f", "mjpeg", 
                "-analyzeduration", "0", 
                "-probesize", "32"
            ]
        cmd += [
            "-i", rtsp_url,
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-g",
            "50",
            "-sc_threshold",
            "0",
            "-an",
            "-f",
            "hls",
            "-hls_time",
            "2",
            "-hls_list_size",
            "6",
            "-hls_flags",
            "independent_segments+append_list",
            "-hls_segment_filename",
            "segment_%03d.ts",
            "index.m3u8",
        ]

        # open subprocess
        try:
            log_file = open(out_dir / "ffmpeg.log", "ab")
            proc = subprocess.Popen(
                cmd,
                stdout=log_file,
                stderr=log_file,
                cwd=str(out_dir),
            )
            logger.info(f"[Stream] Started stream for device {device_id}, PID={proc.pid}")
        except FileNotFoundError:
            # ffmpeg not installed
            logger.error(f"[Stream] ffmpeg not found")
            return None

        _procs[device_id] = {
            'proc': proc,
            'rtsp_url': rtsp_url,
            'log_file': log_file
        }

        # ✅ START AUTO-CAPTURE THREAD
        stop_evt = threading.Event()
        t = threading.Thread(target=_capture_loop, args=(device_id, rtsp_url, stop_evt), daemon=True)
        t.start()
        _capture_threads[device_id] = {'stop_event': stop_evt, 'thread': t}

        return hls_url_for(device_id)


def start_stream_temp(key: str, rtsp_url: str) -> Optional[str]:
    """Start ffmpeg for a temporary key (no DB).
    
    ✅ FIX: Store log_file handle để close properly
    """
    with _lock:
        if key in _temp_procs:
            proc_info = _temp_procs[key]
            proc = proc_info['proc']
            if proc.poll() is not None:
                logger.info(f"[Stream] Temp key {key}: Old process died, restarting...")
                _cleanup_temp_proc(key)
            else:
                logger.debug(f"[Stream] Temp key {key}: Stream already running")
                return hls_url_for_temp(key)

        out_dir = _hls_temp_dir(key)
        index_path = out_dir / "index.m3u8"

        # build ffmpeg command depending on URL scheme
        cmd = ["ffmpeg", "-y"]
        url_lower = rtsp_url.lower()
        if url_lower.startswith('rtsp://'):
            cmd += ["-rtsp_transport", "tcp"]
        else:
             cmd += [
                "-headers", "ngrok-skip-browser-warning: 69420\r\nUser-Agent: FFMPEG", 
                "-f", "mjpeg", 
                "-analyzeduration", "0", 
                "-probesize", "32"
            ]
        cmd += [
            "-i", rtsp_url,
            "-c:v",
            "libx264",
            "-preset",
            "veryfast",
            "-g",
            "50",
            "-sc_threshold",
            "0",
            "-an",
            "-f",
            "hls",
            "-hls_time",
            "2",
            "-hls_list_size",
            "6",
            "-hls_flags",
            "independent_segments+append_list",
            "-hls_segment_filename",
            "segment_%03d.ts",
            "index.m3u8",
        ]

        try:
            log_file = open(out_dir / "ffmpeg.log", "ab")
            proc = subprocess.Popen(
                cmd,
                stdout=log_file,
                stderr=log_file,
                cwd=str(out_dir),
            )
            logger.info(f"[Stream] Started temp stream for key {key}, PID={proc.pid}")
        except FileNotFoundError:
            logger.error(f"[Stream] ffmpeg not found for temp key {key}")
            return None

        _temp_procs[key] = {
            'proc': proc,
            'rtsp_url': rtsp_url,
            'log_file': log_file
        }
        return hls_url_for_temp(key)


def stop_stream(device_id: int) -> bool:
    """Stop stream for device."""
    with _lock:
        # ✅ Stop Capture Thread
        if device_id in _capture_threads:
            logger.info(f"[Stream] Stopping capture thread for device {device_id}")
            _capture_threads[device_id]['stop_event'].set()
            # Don't join() here to avoid blocking
            del _capture_threads[device_id]

        return _cleanup_proc(device_id)


def stop_stream_temp(key: str) -> bool:
    """Stop temp stream.
    
    ✅ FIX: Close log_file và cleanup properly
    """
    with _lock:
        return _cleanup_temp_proc(key)


def _cleanup_proc(device_id: int) -> bool:
    """⚙️ Internal: Cleanup process for device (must hold lock)."""
    proc_info = _procs.get(device_id)
    if not proc_info:
        return False
    
    proc = proc_info['proc']
    log_file = proc_info.get('log_file')
    
    try:
        proc.terminate()
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
    except Exception as e:
        logger.warning(f"[Stream] Error terminating process {device_id}: {e}")
    
    # ✅ Close log file
    if log_file and not log_file.closed:
        try:
            log_file.close()
        except Exception as e:
            logger.warning(f"[Stream] Error closing log file for device {device_id}: {e}")
    
    del _procs[device_id]
    logger.info(f"[Stream] Stopped stream for device {device_id}")
    return True


def _cleanup_temp_proc(key: str) -> bool:
    """⚙️ Internal: Cleanup temp process (must hold lock)."""
    proc_info = _temp_procs.get(key)
    if not proc_info:
        return False
    
    proc = proc_info['proc']
    log_file = proc_info.get('log_file')
    
    try:
        proc.terminate()
        proc.wait(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
    except Exception as e:
        logger.warning(f"[Stream] Error terminating temp process {key}: {e}")
    
    # ✅ Close log file
    if log_file and not log_file.closed:
        try:
            log_file.close()
        except Exception as e:
            logger.warning(f"[Stream] Error closing log file for temp key {key}: {e}")
    
    del _temp_procs[key]
    logger.info(f"[Stream] Stopped temp stream for key {key}")
    return True


def is_running(device_id: int) -> bool:
    with _lock:
        proc_info = _procs.get(device_id)
        if not proc_info:
            return False
        proc = proc_info['proc']
        return proc.poll() is None


def is_running_temp(key: str) -> bool:
    with _lock:
        proc_info = _temp_procs.get(key)
        if not proc_info:
            return False
        proc = proc_info['proc']
        return proc.poll() is None


def get_stream_info(device_id: int) -> Optional[dict]:
    """Get stream info for device (URL, PID, status)."""
    with _lock:
        proc_info = _procs.get(device_id)
        if not proc_info:
            return None
        
        proc = proc_info['proc']
        is_running_now = proc.poll() is None
        
        return {
            'device_id': device_id,
            'rtsp_url': proc_info.get('rtsp_url'),
            'hls_url': hls_url_for(device_id),
            'running': is_running_now,
            'pid': proc.pid if is_running_now else None
        }


def list_active_streams() -> list[dict]:
    """List all active streams."""
    with _lock:
        result = []
        for device_id, proc_info in _procs.items():
            proc = proc_info['proc']
            if proc.poll() is None:  # Still running
                result.append({
                    'device_id': device_id,
                    'rtsp_url': proc_info.get('rtsp_url'),
                    'hls_url': hls_url_for(device_id),
                    'running': True,
                    'pid': proc.pid
                })
        return result


def check_stream_health(device_id: int) -> dict:
    """Check if stream is healthy by verifying process and HLS files.
    
    Returns:
        dict: {
            'healthy': bool,
            'running': bool,
            'error': str | None,
            'hls_exists': bool,
            'last_update': float | None  # seconds ago
        }
    """
    with _lock:
        proc_info = _procs.get(device_id)
        
        if not proc_info:
            # ✅ FALLBACK: Check OpenCV Stream (New Approach)
            # Chúng ta cần tra cứu URL từ DB để lấy session_id
            try:
                db = SessionLocal()
                from app.models.devices import Device
                import hashlib
                from app.services.opencv_hls_service import get_stream_status
                
                device = db.query(Device).filter(Device.device_id == device_id).first()
                if device and device.stream_url:
                    session_id = hashlib.md5(device.stream_url.encode()).hexdigest()[:8]
                    status = get_stream_status(session_id)
                    
                    if status:
                        # Map OpenCV status to Health dict
                        return {
                            'healthy': status['running'] and status['playlist_exists'],
                            'running': status['running'],
                            'error': status.get('error'),
                            'hls_exists': status['playlist_exists'],
                            'last_update': status['uptime'],
                            'type': 'opencv'
                        }
            except Exception as e:
                logger.error(f"[StreamHealth] Error checking OpenCV stream: {e}")
            finally:
                if 'db' in locals():
                    db.close()

            # Nếu không tìm thấy ở cả 2 nơi
            return {
                'healthy': False,
                'running': False,
                'error': 'Stream chưa được khởi động',
                'hls_exists': False,
                'last_update': None
            }
        
        proc = proc_info['proc']
        is_running = proc.poll() is None
        
        if not is_running:
            return {
                'healthy': False,
                'running': False,
                'error': 'Quá trình stream đã dừng',
                'hls_exists': False,
                'last_update': None
            }
        
        # Check HLS files
        hls_dir = _hls_dir(device_id)
        index_file = hls_dir / "index.m3u8"
        
        if not index_file.exists():
            return {
                'healthy': False,
                'running': True,
                'error': 'Đang chờ stream khởi tạo...',
                'hls_exists': False,
                'last_update': None
            }
        
        # Check for recent .ts segments
        import time
        ts_files = sorted(hls_dir.glob("*.ts"), key=lambda p: p.stat().st_mtime, reverse=True)
        
        if not ts_files:
            return {
                'healthy': False,
                'running': True,
                'error': 'Không có dữ liệu video',
                'hls_exists': True,
                'last_update': None
            }
        
        # Check if latest segment is recent (within 10 seconds)
        latest_ts = ts_files[0]
        last_modified = latest_ts.stat().st_mtime
        seconds_ago = time.time() - last_modified
        
        if seconds_ago > 10:
            return {
                'healthy': False,
                'running': True,
                'error': f'Stream không cập nhật (dừng {int(seconds_ago)}s trước)',
                'hls_exists': True,
                'last_update': seconds_ago
            }
        
        return {
            'healthy': True,
            'running': True,
            'error': None,
            'hls_exists': True,
            'last_update': seconds_ago
        }


