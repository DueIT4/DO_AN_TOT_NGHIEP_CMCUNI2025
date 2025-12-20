# app/services/camera_service.py
"""
Service để lấy ảnh từ camera stream_url
Hỗ trợ: HTTP snapshot, RTSP (cần ffmpeg/opencv), MJPEG stream, lấy frame từ HLS (.ts)
"""
import logging
from io import BytesIO
from pathlib import Path
from typing import Optional

import requests
from PIL import Image

logger = logging.getLogger(__name__)

# OpenCV chỉ import khi cần (cho RTSP/HLS)
try:
    import cv2
    import numpy as np  # noqa: F401
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False
    logger.warning("OpenCV không có sẵn, RTSP/HLS sẽ không hoạt động")

def capture_image_from_stream(stream_url: str, timeout: int = 10) -> Optional[bytes]:
    """
    Lấy ảnh từ camera stream_url.

    Hỗ trợ:
    - HTTP snapshot: http://ip:port/snapshot.jpg
    - MJPEG stream: http://ip:port/video.mjpg
    - RTSP: rtsp://ip:port/stream (cần opencv)

    Returns:
        bytes: Dữ liệu ảnh (JPEG) hoặc None nếu lỗi
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
                # MJPEG stream - lấy frame đầu tiên (đọc chunk)
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
    """Lấy frame đầu tiên từ MJPEG stream bằng cách đọc theo chunk.

    max_bytes: giới hạn đọc để tránh treo/ăn RAM.
    """
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
    """
    Lấy ảnh từ RTSP stream bằng OpenCV.
    Hỗ trợ DroidCam và các RTSP cameras khác.
    Cần cài: pip install opencv-python-headless
    """
    if not CV2_AVAILABLE:
        logger.warning("[Camera] OpenCV không có sẵn, không thể lấy RTSP stream")
        return None

    try:
        # Cấu hình OpenCV cho RTSP tốt hơn
        cap = cv2.VideoCapture(rtsp_url, cv2.CAP_FFMPEG)
        
        # Set các properties để tăng khả năng kết nối
        try:
            cap.set(cv2.CAP_PROP_OPEN_TIMEOUT_MSEC, timeout * 1000)
            cap.set(cv2.CAP_PROP_READ_TIMEOUT_MSEC, timeout * 1000)
            # Giảm buffer để lấy frame mới nhất
            cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            # Tăng tốc độ khởi tạo
            cap.set(cv2.CAP_PROP_FPS, 30)
        except Exception as e:
            logger.debug(f"[Camera] Không set được timeout properties: {e}")

        if not cap.isOpened():
            logger.warning(f"[Camera] Cannot open RTSP stream: {rtsp_url}")
            return None

        # Thử đọc frame nhiều lần để đảm bảo lấy được frame ổn định
        ret, frame = False, None
        for attempt in range(3):
            ret, frame = cap.read()
            if ret and frame is not None:
                break
            logger.debug(f"[Camera] RTSP read attempt {attempt + 1}/3 failed")
        
        cap.release()

        if not ret or frame is None:
            logger.warning(f"[Camera] Không đọc được frame từ RTSP: {rtsp_url}")
            return None

        # Chuyển BGR sang RGB và encode thành JPEG
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(frame_rgb)
        output = BytesIO()
        img.save(output, format="JPEG", quality=85)
        logger.info(f"[Camera] Successfully captured from RTSP: {rtsp_url}")
        return output.getvalue()

    except Exception as e:
        logger.error(f"[Camera] Error capturing RTSP: {e}")
        return None

def _capture_image_from_hls(device_id: int) -> Optional[bytes]:
    """Lấy một frame từ HLS đã được stream_service tạo sẵn.
    Ưu tiên dùng khi RTSP bị độc quyền bởi ffmpeg.
    """
    if not CV2_AVAILABLE:
        return None

    try:
        hls_dir = Path("media") / "hls" / str(device_id)
        if not hls_dir.exists():
            return None

        segments = sorted(
            hls_dir.glob("*.ts"),
            key=lambda p: p.stat().st_mtime,
            reverse=True,
        )
        if not segments:
            return None

        latest = segments[0]
        cap = cv2.VideoCapture(str(latest))
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
) -> list[bytes]:
    """
    Lấy nhiều ảnh từ camera (để tăng độ chính xác).

    Args:
        stream_url: URL của camera stream
        count: Số lượng ảnh cần lấy (mặc định 3)
        interval: Khoảng thời gian giữa các lần lấy (giây)
        device_id: nếu có, thử lấy từ HLS trước

    Returns:
        List các ảnh (bytes), có thể ít hơn count nếu lỗi
    """
    import time

    images: list[bytes] = []
    for i in range(count):
        img_data = None

        if device_id is not None:
            img_data = _capture_image_from_hls(device_id)

        if img_data is None:
            img_data = capture_image_from_stream(stream_url)

        if img_data:
            images.append(img_data)

        if i < count - 1:
            time.sleep(interval)

    return images