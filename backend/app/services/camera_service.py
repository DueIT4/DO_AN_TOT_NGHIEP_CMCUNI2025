# app/services/camera_service.py
"""
Service để lấy ảnh từ camera stream_url
Hỗ trợ: HTTP snapshot, RTSP (cần ffmpeg/opencv), MJPEG stream, lấy frame từ HLS (.ts)
Tối ưu hóa cho Google Cloud Run (/tmp storage)
"""
import logging
import time
from io import BytesIO
from pathlib import Path
from typing import Optional, List

import requests
from PIL import Image

logger = logging.getLogger(__name__)

# OpenCV chỉ import khi cần (cho RTSP/HLS)
try:
    import cv2
    import numpy as np
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False
    logger.warning("OpenCV không có sẵn, RTSP/HLS sẽ không hoạt động")

def capture_image_from_stream(stream_url: str, timeout: int = 10) -> Optional[bytes]:
    """
    Lấy ảnh từ camera stream_url.
    Hỗ trợ: HTTP snapshot, MJPEG stream, RTSP.
    """
    if not stream_url or not stream_url.strip():
        return None

    stream_url = stream_url.strip()

    try:
        # ===== HTTP SNAPSHOT / MJPEG =====
        if stream_url.startswith("http://") or stream_url.startswith("https://"):
            resp = requests.get(stream_url, timeout=timeout, stream=True)
            resp.raise_for_status()

            content_type = (resp.headers.get("content-type") or "").lower()

            if "image" in content_type:
                # Ảnh tĩnh (snapshot)
                return resp.content

            if "multipart" in content_type or "mjpeg" in content_type:
                # MJPEG stream - lấy frame đầu tiên
                return _extract_frame_from_mjpeg(resp)

            # Fallback: thử parse như ảnh
            img = Image.open(BytesIO(resp.content))
            output = BytesIO()
            img.save(output, format="JPEG", quality=85)
            return output.getvalue()

        # ===== RTSP STREAM =====
        if stream_url.startswith("rtsp://"):
            return _capture_from_rtsp(stream_url, timeout)

        logger.warning(f"[Camera] Unsupported stream URL format: {stream_url}")
        return None

    except requests.exceptions.RequestException as e:
        logger.error(f"[Camera] Error fetching from {stream_url}: {e}")
        return None
    except Exception as e:
        logger.error(f"[Camera] Unexpected error: {e}")
        return None

def _extract_frame_from_mjpeg(resp: requests.Response, max_bytes: int = 2_000_000) -> Optional[bytes]:
    """Lấy frame đầu tiên từ MJPEG stream."""
    try:
        buffer = bytearray()
        start = -1

        for chunk in resp.iter_content(chunk_size=4096):
            if not chunk:
                continue
            buffer.extend(chunk)

            if start == -1:
                start = buffer.find(b"\xff\xd8")  # JPEG start
                if start == -1:
                    if len(buffer) > max_bytes:
                        return None
                    continue

            end = buffer.find(b"\xff\xd9", start)  # JPEG end
            if end != -1:
                return bytes(buffer[start:end + 2])

            if len(buffer) > max_bytes:
                return None

        return None
    except Exception as e:
        logger.error(f"[Camera] Error extracting MJPEG frame: {e}")
        return None

def _capture_from_rtsp(rtsp_url: str, timeout: int = 10) -> Optional[bytes]:
    """Lấy ảnh từ RTSP stream bằng OpenCV."""
    if not CV2_AVAILABLE:
        logger.warning("[Camera] OpenCV không có sẵn, không thể lấy RTSP stream")
        return None

    try:
        cap = cv2.VideoCapture(rtsp_url, cv2.CAP_FFMPEG)
        
        try:
            cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, timeout * 1000)
            cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, timeout * 1000)
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
        except Exception: pass

        if not cap.isOpened():
            return None

        ret, frame = False, None
        for _ in range(3):
            ret, frame = cap.read()
            if ret and frame is not None:
                break
        
        cap.release()

        if not ret or frame is None:
            return None

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(frame_rgb)
        output = BytesIO()
        img.save(output, format="JPEG", quality=85)
        return output.getvalue()

    except Exception as e:
        logger.error(f"[Camera] Error capturing RTSP: {e}")
        return None

def _capture_image_from_hls(device_id: int) -> Optional[bytes]:
    """
    Lấy frame từ HLS. 
    ✅ CẬP NHẬT: Sử dụng /tmp/hls để tương thích với Google Cloud Run.
    """
    if not CV2_AVAILABLE:
        return None

    try:
        # Sử dụng thư mục tạm /tmp thay vì media/
        hls_dir = Path("/tmp/hls") / str(device_id)
        if not hls_dir.exists():
            return None

        # Lấy segment (.ts) mới nhất dựa trên thời gian chỉnh sửa
        segments = sorted(
            hls_dir.glob("*.ts"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        if not segments:
            return None

        latest = segments[0]
        cap = cv2.VideoCapture(str(latest.absolute()))
        if not cap.isOpened():
            return None

        ret, frame = cap.read()
        cap.release()
        if not ret or frame is None:
            return None

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(frame_rgb)
        output = BytesIO()
        img.save(output, format="JPEG", quality=85)
        return output.getvalue()

    except Exception as e:
        logger.error(f"[Camera] Error capturing HLS frame for device {device_id}: {e}")
        return None

def capture_multiple_images(
    stream_url: str,
    count: int = 3,
    interval: float = 1.0,
    device_id: Optional[int] = None,
) -> List[bytes]:
    """Lấy nhiều ảnh từ camera để tăng độ chính xác."""
    images: List[bytes] = []
    for i in range(count):
        img_data = None

        # Thử lấy từ HLS cache (/tmp) trước nếu có device_id
        if device_id is not None:
            img_data = _capture_image_from_hls(device_id)

        # Nếu không có HLS hoặc thất bại, lấy trực tiếp từ stream URL
        if img_data is None:
            img_data = capture_image_from_stream(stream_url)

        if img_data:
            images.append(img_data)

        if i < count - 1:
            time.sleep(interval)

    return images