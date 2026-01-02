import subprocess
import os
import threading
from typing import Optional
from pathlib import Path
import shutil
import logging
import time

logger = logging.getLogger(__name__)

# {device_id: {'proc': Popen, 'rtsp_url': str, 'log_file': file_obj}}
_procs = {}  
# {key: {'proc': Popen, 'rtsp_url': str, 'log_file': file_obj}}
_temp_procs = {}  
_lock = threading.Lock()

# ✅ Tối ưu cho Google Cloud Run: Sử dụng /tmp để lưu file playlist và segments
# /tmp là thư mục duy nhất có quyền ghi trên Cloud Run (dùng RAM)
HLS_ROOT = Path("/tmp/hls")
HLS_ROOT.mkdir(parents=True, exist_ok=True)


def _hls_dir(device_id: int) -> Path:
    d = HLS_ROOT / str(device_id)
    d.mkdir(parents=True, exist_ok=True)
    return d


def hls_url_for(device_id: int) -> str:
    # URL này sẽ được routes_stream.py xử lý để trả về file từ /tmp
    return f"/api/v1/stream/hls/playlist/{device_id}/index.m3u8"


def _hls_temp_dir(key: str) -> Path:
    d = HLS_ROOT / f"temp-{key}"
    d.mkdir(parents=True, exist_ok=True)
    return d


def hls_url_for_temp(key: str) -> str:
    return f"/api/v1/stream/hls/playlist/temp-{key}/index.m3u8"


def start_stream(device_id: int, rtsp_url: str) -> Optional[str]:
    """Khởi động ffmpeg để chuyển đổi RTSP/MJPEG -> HLS."""
    with _lock:
        if device_id in _procs:
            proc_info = _procs[device_id]
            old_rtsp = proc_info.get('rtsp_url')
            
            if old_rtsp != rtsp_url:
                logger.info(f"[Stream] Device {device_id}: RTSP URL thay đổi, đang dừng luồng cũ")
                _cleanup_proc(device_id)
            else:
                proc = proc_info['proc']
                if proc.poll() is not None:
                    logger.info(f"[Stream] Device {device_id}: Tiến trình cũ đã chết, đang khởi động lại...")
                    _cleanup_proc(device_id)
                else:
                    logger.debug(f"[Stream] Device {device_id}: Luồng đã đang chạy")
                    return hls_url_for(device_id)

        out_dir = _hls_dir(device_id)
        
        # ✅ Tối ưu hóa lệnh FFmpeg cho môi trường Cloud (ít tài nguyên)
        ffmpeg_path = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"
        
        cmd = [ffmpeg_path, "-y"]
        url_lower = rtsp_url.lower()
        if url_lower.startswith('rtsp://'):
            cmd += ["-rtsp_transport", "tcp"]
        else:
            cmd += ["-f", "mjpeg", "-analyzeduration", "0", "-probesize", "32"]
            
        cmd += [
            "-i", rtsp_url,
            "-c:v", "libx264",
            "-preset", "ultrafast",  # ✅ ultrafast để tiết kiệm CPU trên Cloud Run
            "-tune", "zerolatency",
            "-g", "50",
            "-sc_threshold", "0",
            "-an",
            "-f", "hls",
            "-hls_time", "2",
            "-hls_list_size", "4",   # ✅ Giảm xuống 4 để tiết kiệm dung lượng /tmp (RAM)
            "-hls_flags", "delete_segments+independent_segments+append_list",
            "-hls_segment_filename", "segment_%03d.ts",
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
            logger.info(f"[Stream] Đã bắt đầu stream cho thiết bị {device_id}, PID={proc.pid}")
        except FileNotFoundError:
            logger.error(f"[Stream] Không tìm thấy lệnh ffmpeg trong hệ thống")
            return None

        _procs[device_id] = {
            'proc': proc,
            'rtsp_url': rtsp_url,
            'log_file': log_file
        }
        return hls_url_for(device_id)


def start_stream_temp(key: str, rtsp_url: str) -> Optional[str]:
    """Bắt đầu stream tạm thời (không lưu DB)."""
    with _lock:
        if key in _temp_procs:
            proc_info = _temp_procs[key]
            proc = proc_info['proc']
            if proc.poll() is not None:
                _cleanup_temp_proc(key)
            else:
                return hls_url_for_temp(key)

        out_dir = _hls_temp_dir(key)
        ffmpeg_path = shutil.which("ffmpeg") or "/usr/bin/ffmpeg"

        cmd = [ffmpeg_path, "-y"]
        if rtsp_url.lower().startswith('rtsp://'):
            cmd += ["-rtsp_transport", "tcp"]
        else:
            cmd += ["-f", "mjpeg", "-analyzeduration", "0", "-probesize", "32"]

        cmd += [
            "-i", rtsp_url,
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
            "-f", "hls",
            "-hls_time", "2",
            "-hls_list_size", "4",
            "-hls_flags", "delete_segments+append_list",
            "-hls_segment_filename", "segment_%03d.ts",
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
            logger.info(f"[Stream] Đã bắt đầu stream tạm thời {key}, PID={proc.pid}")
        except FileNotFoundError:
            return None

        _temp_procs[key] = {
            'proc': proc,
            'rtsp_url': rtsp_url,
            'log_file': log_file
        }
        return hls_url_for_temp(key)


def stop_stream(device_id: int) -> bool:
    with _lock:
        return _cleanup_proc(device_id)


def stop_stream_temp(key: str) -> bool:
    with _lock:
        return _cleanup_temp_proc(key)


def _cleanup_proc(device_id: int) -> bool:
    proc_info = _procs.get(device_id)
    if not proc_info:
        return False
    
    proc = proc_info['proc']
    log_file = proc_info.get('log_file')
    
    try:
        proc.terminate()
        proc.wait(timeout=3)
    except Exception:
        proc.kill()
    
    if log_file and not log_file.closed:
        try:
            log_file.close()
        except Exception: pass
    
    del _procs[device_id]
    
    # Xóa thư mục tạm của session này để giải phóng RAM (/tmp)
    try:
        shutil.rmtree(_hls_dir(device_id), ignore_errors=True)
    except Exception: pass
    
    logger.info(f"[Stream] Đã dừng và dọn dẹp stream cho thiết bị {device_id}")
    return True


def _cleanup_temp_proc(key: str) -> bool:
    proc_info = _temp_procs.get(key)
    if not proc_info:
        return False
    
    proc = proc_info['proc']
    log_file = proc_info.get('log_file')
    
    try:
        proc.terminate()
        proc.wait(timeout=3)
    except Exception:
        proc.kill()
    
    if log_file and not log_file.closed:
        try:
            log_file.close()
        except Exception: pass
    
    del _temp_procs[key]
    
    try:
        shutil.rmtree(_hls_temp_dir(key), ignore_errors=True)
    except Exception: pass
    
    return True


def is_running(device_id: int) -> bool:
    with _lock:
        proc_info = _procs.get(device_id)
        if not proc_info:
            return False
        return proc_info['proc'].poll() is None


def is_running_temp(key: str) -> bool:
    with _lock:
        proc_info = _temp_procs.get(key)
        if not proc_info:
            return False
        return proc_info['proc'].poll() is None


def get_stream_info(device_id: int) -> Optional[dict]:
    with _lock:
        proc_info = _procs.get(device_id)
        if not proc_info:
            return None
        
        proc = proc_info['proc']
        running = proc.poll() is None
        
        return {
            'device_id': device_id,
            'rtsp_url': proc_info.get('rtsp_url'),
            'hls_url': hls_url_for(device_id),
            'running': running,
            'pid': proc.pid if running else None
        }


def list_active_streams() -> list[dict]:
    with _lock:
        result = []
        for device_id, proc_info in _procs.items():
            proc = proc_info['proc']
            if proc.poll() is None:
                result.append({
                    'device_id': device_id,
                    'rtsp_url': proc_info.get('rtsp_url'),
                    'hls_url': hls_url_for(device_id),
                    'running': True,
                    'pid': proc.pid
                })
        return result


def check_stream_health(device_id: int) -> dict:
    """Kiểm tra sức khỏe của luồng dựa trên tiến trình và file HLS."""
    with _lock:
        proc_info = _procs.get(device_id)
        
        if not proc_info:
            return {'healthy': False, 'running': False, 'error': 'Chưa bắt đầu'}
        
        proc = proc_info['proc']
        running = proc.poll() is None
        
        if not running:
            return {'healthy': False, 'running': False, 'error': 'Tiến trình đã dừng'}
        
        hls_dir = _hls_dir(device_id)
        index_file = hls_dir / "index.m3u8"
        
        if not index_file.exists():
            return {'healthy': False, 'running': True, 'error': 'Đang chờ khởi tạo file HLS...'}
        
        ts_files = sorted(hls_dir.glob("*.ts"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not ts_files:
            return {'healthy': False, 'running': True, 'error': 'Không có dữ liệu video (.ts)'}
        
        latest_ts = ts_files[0]
        seconds_ago = time.time() - latest_ts.stat().st_mtime
        
        # Nếu quá 10 giây không có segment mới -> Unhealthy
        healthy = seconds_ago < 10
        
        return {
            'healthy': healthy,
            'running': True,
            'error': None if healthy else f'Luồng bị treo ({int(seconds_ago)}s trước)',
            'hls_exists': True,
            'last_update': seconds_ago
        }