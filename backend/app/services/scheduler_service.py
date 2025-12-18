# app/services/scheduler_service.py
"""
Scheduler để tự động quét ảnh từ camera mỗi 30s (từ stream video đang chạy)
- Nếu phát hiện bệnh → gửi notification
- Nếu cây bình thường → không báo
"""
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
from sqlalchemy.orm import Session
from app.core.database import SessionLocal
from app.models.devices import Device
from app.models.device_type import DeviceType
from app.services.auto_detection_service import detect_from_camera_auto
import logging

logger = logging.getLogger(__name__)

# Global scheduler instance
scheduler = BackgroundScheduler()

# Track active auto-detection devices
_auto_detect_devices = set()  # {device_id, ...}
_auto_detect_lock = __import__('threading').Lock()


def is_auto_detect_enabled(device_id: int) -> bool:
    """Check if auto-detection is enabled for device."""
    with _auto_detect_lock:
        return device_id in _auto_detect_devices


def enable_auto_detect(device_id: int) -> bool:
    """Enable auto-detection for device."""
    with _auto_detect_lock:
        if device_id not in _auto_detect_devices:
            _auto_detect_devices.add(device_id)
            logger.info(f"[Scheduler] Đã bật auto-detection cho device {device_id}")
            return True
        return False


def disable_auto_detect(device_id: int) -> bool:
    """Disable auto-detection for device."""
    with _auto_detect_lock:
        if device_id in _auto_detect_devices:
            _auto_detect_devices.discard(device_id)
            logger.info(f"[Scheduler] Đã tắt auto-detection cho device {device_id}")
            return True
        return False


def scan_devices_for_auto_detection():
    """
    Quét tất cả devices có auto-detection bật.
    Mỗi device sẽ:
    1. Lấy 1 ảnh từ stream hiện tại
    2. Chạy YOLO detection
    3. Nếu có bệnh → gửi notification
    4. Nếu cây bình thường → không báo (skip notification)
    """
    db: Session = SessionLocal()
    try:
        with _auto_detect_lock:
            devices_to_scan = list(_auto_detect_devices)
        
        if not devices_to_scan:
            logger.debug("[Scheduler] Không có device nào có auto-detection bật")
            return

        logger.info(f"[Scheduler] Bắt đầu quét {len(devices_to_scan)} devices...")
        
        for device_id in devices_to_scan:
            try:
                device = db.get(Device, device_id)
                if not device:
                    logger.warning(f"[Scheduler] Device {device_id} không tìm thấy, vô hiệu hóa auto-detect")
                    disable_auto_detect(device_id)
                    continue
                
                if device.status != 'active' or not device.stream_url:
                    logger.debug(f"[Scheduler] Device {device_id} không active hoặc không có stream_url, bỏ qua")
                    continue

                logger.debug(f"[Scheduler] Quét device: {device.name} (ID: {device_id})")
                
                # ✅ AUTO-DETECT: Lấy 1 ảnh từ stream, phân tích, tự stop stream
                # auto_stop_stream=True → stream sẽ stop sau detection
                # Điều này giúp tránh resource leak và cho phép stream được khởi động lại
                result = detect_from_camera_auto(
                    db, 
                    device, 
                    num_images=1,  # Chỉ lấy 1 ảnh (đủ nhanh)
                    auto_stop_stream=False  # Keep stream running để frontend vẫn xem video
                )
                
                if result.get('success'):
                    detections_count = result.get('detections_count', 0)
                    has_disease = result.get('has_disease', False)
                    
                    if has_disease:
                        logger.warning(f"[Scheduler] ⚠️ Device {device_id}: Phát hiện bệnh! ({detections_count} detections)")
                    else:
                        logger.debug(f"[Scheduler] ✓ Device {device_id}: Cây bình thường ({detections_count} detections)")
                else:
                    logger.warning(f"[Scheduler] ✗ Device {device_id}: {result.get('error', 'Unknown error')}")
                    
            except Exception as e:
                logger.error(f"[Scheduler] Lỗi khi quét device {device_id}: {e}", exc_info=True)
        
        logger.info(f"[Scheduler] Hoàn thành quét {len(devices_to_scan)} devices")
        
    except Exception as e:
        logger.error(f"[Scheduler] Lỗi chung trong scan_devices_for_auto_detection: {e}", exc_info=True)
    finally:
        db.close()


def start_scheduler():
    """
    Khởi động scheduler - chạy auto-detect mỗi 30 giây cho các devices được enable.
    """
    if scheduler.running:
        logger.warning("[Scheduler] Scheduler đã chạy rồi!")
        return
    
    # ✅ PRODUCTION: Mỗi 30 giây
    scheduler.add_job(
        scan_devices_for_auto_detection,
        trigger=IntervalTrigger(seconds=30),
        id='auto_detect_every_30s',
        name='Auto-detect từ stream mỗi 30 giây',
        replace_existing=True,
        max_instances=1,  # Chỉ chạy 1 instance lúc nào
        coalesce=True,    # Nếu bị delay thì skip job cũ, chạy job mới
        misfire_grace_time=10
    )

    scheduler.start()
    logger.info("[Scheduler] ✅ Đã khởi động scheduler - Auto-detect mỗi 30 giây")


def stop_scheduler():
    """
    Dừng scheduler
    """
    if scheduler.running:
        scheduler.shutdown()
        logger.info("[Scheduler] Đã dừng scheduler")
        
        
def get_auto_detect_status() -> dict:
    """Get current auto-detection status."""
    with _auto_detect_lock:
        return {
            "scheduler_running": scheduler.running,
            "active_devices": list(_auto_detect_devices),
            "count": len(_auto_detect_devices)
        }
