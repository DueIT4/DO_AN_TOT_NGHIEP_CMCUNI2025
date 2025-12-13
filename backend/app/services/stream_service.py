import subprocess
import os
import threading
from typing import Optional
from pathlib import Path

_procs = {}
_temp_procs = {}
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


def start_stream(device_id: int, rtsp_url: str) -> Optional[str]:
    """Start ffmpeg to transcode RTSP -> HLS for the given device.
    Returns HLS index path (relative) or None on failure.
    """
    with _lock:
        if device_id in _procs:
            proc = _procs[device_id]
            # nếu process đã chết, dọn dẹp để khởi động lại
            if proc.poll() is not None:
                try:
                    proc.kill()
                except Exception:
                    pass
                _procs.pop(device_id, None)
            else:
                # đang chạy -> trả về HLS hiện tại
                return hls_url_for(device_id)

        out_dir = _hls_dir(device_id)
        index_path = out_dir / "index.m3u8"

        # ffmpeg command: re-encode to H.264 + AAC and produce short HLS segments
        # build ffmpeg command depending on URL scheme
        cmd = ["ffmpeg", "-y"]
        url_lower = rtsp_url.lower()
        if url_lower.startswith('rtsp://'):
            cmd += ["-rtsp_transport", "tcp"]
        else:
            # DroidCam / HTTP MJPEG streams need explicit demuxer
            cmd += ["-f", "mjpeg", "-analyzeduration", "0", "-probesize", "32"]
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
        except FileNotFoundError:
            # ffmpeg not installed
            return None

        _procs[device_id] = proc
        return hls_url_for(device_id)


def start_stream_temp(key: str, rtsp_url: str) -> Optional[str]:
    """Start ffmpeg for a temporary key (no DB)."""
    with _lock:
        if key in _temp_procs:
            proc = _temp_procs[key]
            if proc.poll() is not None:
                try:
                    proc.kill()
                except Exception:
                    pass
                _temp_procs.pop(key, None)
            else:
                return hls_url_for_temp(key)

        out_dir = _hls_temp_dir(key)
        index_path = out_dir / "index.m3u8"

        # build ffmpeg command depending on URL scheme
        cmd = ["ffmpeg", "-y"]
        url_lower = rtsp_url.lower()
        if url_lower.startswith('rtsp://'):
            cmd += ["-rtsp_transport", "tcp"]
        else:
            cmd += ["-f", "mjpeg", "-analyzeduration", "0", "-probesize", "32"]
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
        except FileNotFoundError:
            return None

        _temp_procs[key] = proc
        return hls_url_for_temp(key)


def stop_stream(device_id: int) -> bool:
    with _lock:
        proc = _procs.get(device_id)
        if not proc:
            return False
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
        del _procs[device_id]
        return True


def stop_stream_temp(key: str) -> bool:
    with _lock:
        proc = _temp_procs.get(key)
        if not proc:
            return False
        proc.terminate()
        try:
            proc.wait(timeout=5)
        except Exception:
            proc.kill()
        del _temp_procs[key]
        return True


def is_running(device_id: int) -> bool:
    with _lock:
        proc = _procs.get(device_id)
        return proc is not None and proc.poll() is None


def is_running_temp(key: str) -> bool:
    with _lock:
        proc = _temp_procs.get(key)
        return proc is not None and proc.poll() is None
