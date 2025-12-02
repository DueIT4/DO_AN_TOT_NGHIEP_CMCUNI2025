# app/services/camera_service.py
"""
Service để lấy ảnh từ camera stream_url
Hỗ trợ: HTTP snapshot, RTSP (cần ffmpeg), MJPEG stream
"""
import requests
from typing import Optional
from io import BytesIO
from PIL import Image
import logging

logger = logging.getLogger(__name__)

# OpenCV chỉ import khi cần (cho RTSP)
try:
    import cv2
    import numpy as np
    CV2_AVAILABLE = True
except ImportError:
    CV2_AVAILABLE = False
    logger.warning("OpenCV không có sẵn, RTSP stream sẽ không hoạt động")

def capture_image_from_stream(stream_url: str, timeout: int = 10) -> Optional[bytes]:
    """
    Lấy ảnh từ camera stream_url.
    
    Hỗ trợ:
    - HTTP snapshot: http://ip:port/snapshot.jpg
    - MJPEG stream: http://ip:port/video.mjpg
    - RTSP: rtsp://ip:port/stream (cần ffmpeg/opencv)
    
    Returns:
        bytes: Dữ liệu ảnh (JPEG) hoặc None nếu lỗi
    """
    if not stream_url or not stream_url.strip():
        return None
    
    stream_url = stream_url.strip()
    
    try:
        # ===== HTTP SNAPSHOT (phổ biến nhất) =====
        if stream_url.startswith('http://') or stream_url.startswith('https://'):
            # Thử lấy snapshot trực tiếp
            response = requests.get(stream_url, timeout=timeout, stream=True)
            response.raise_for_status()
            
            # Kiểm tra content-type
            content_type = response.headers.get('content-type', '').lower()
            
            if 'image' in content_type:
                # Là ảnh tĩnh (snapshot)
                return response.content
            elif 'multipart' in content_type or 'mjpeg' in content_type:
                # MJPEG stream - lấy frame đầu tiên
                return _extract_frame_from_mjpeg(response)
            else:
                # Thử parse như ảnh
                img = Image.open(BytesIO(response.content))
                output = BytesIO()
                img.save(output, format='JPEG')
                return output.getvalue()
        
        # ===== RTSP STREAM =====
        elif stream_url.startswith('rtsp://'):
            return _capture_from_rtsp(stream_url, timeout)
        
        else:
            logger.warning(f"[Camera] Unsupported stream URL format: {stream_url}")
            return None
            
    except requests.exceptions.RequestException as e:
        logger.error(f"[Camera] Error fetching from {stream_url}: {e}")
        return None
    except Exception as e:
        logger.error(f"[Camera] Unexpected error: {e}")
        return None

def _extract_frame_from_mjpeg(response) -> Optional[bytes]:
    """Lấy frame đầu tiên từ MJPEG stream"""
    try:
        # MJPEG stream có format: --boundary\nContent-Type: image/jpeg\n\n<image_data>--boundary
        content = response.content
        # Tìm JPEG marker
        jpeg_start = content.find(b'\xff\xd8')
        if jpeg_start == -1:
            return None
        
        jpeg_end = content.find(b'\xff\xd9', jpeg_start)
        if jpeg_end == -1:
            return None
        
        jpeg_data = content[jpeg_start:jpeg_end + 2]
        return jpeg_data
    except Exception as e:
        logger.error(f"[Camera] Error extracting MJPEG frame: {e}")
        return None

def _capture_from_rtsp(rtsp_url: str, timeout: int = 10) -> Optional[bytes]:
    """
    Lấy ảnh từ RTSP stream bằng OpenCV.
    Cần cài: pip install opencv-python-headless
    """
    if not CV2_AVAILABLE:
        logger.warning("[Camera] OpenCV không có sẵn, không thể lấy RTSP stream")
        return None
    
    try:
        cap = cv2.VideoCapture(rtsp_url)
        cap.set(cv2.CAP_PROP_TIMEOUT, timeout * 1000)  # milliseconds
        
        if not cap.isOpened():
            logger.warning(f"[Camera] Cannot open RTSP stream: {rtsp_url}")
            return None
        
        ret, frame = cap.read()
        cap.release()
        
        if not ret or frame is None:
            return None
        
        # Convert BGR to RGB và encode thành JPEG
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        img = Image.fromarray(frame_rgb)
        output = BytesIO()
        img.save(output, format='JPEG', quality=85)
        return output.getvalue()
        
    except Exception as e:
        logger.error(f"[Camera] Error capturing RTSP: {e}")
        return None

def capture_multiple_images(stream_url: str, count: int = 3, interval: float = 1.0) -> list[bytes]:
    """
    Lấy nhiều ảnh từ camera (để tăng độ chính xác).
    
    Args:
        stream_url: URL của camera stream
        count: Số lượng ảnh cần lấy (mặc định 3)
        interval: Khoảng thời gian giữa các lần lấy (giây)
    
    Returns:
        List các ảnh (bytes), có thể ít hơn count nếu lỗi
    """
    import time
    
    images = []
    for i in range(count):
        img_data = capture_image_from_stream(stream_url)
        if img_data:
            images.append(img_data)
        
        # Chờ trước khi lấy ảnh tiếp theo (trừ lần cuối)
        if i < count - 1:
            time.sleep(interval)
    
    return images

