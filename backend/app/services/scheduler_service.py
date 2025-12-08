# app/services/scheduler_service.py
"""
Scheduler để tự động quét ảnh từ camera 2 lần/ngày
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

scheduler = BackgroundScheduler()

def scan_all_cameras():
    """
    Quét tất cả camera có stream_url và status = 'active'
    """
    db: Session = SessionLocal()
    try:
        # Lấy tất cả devices có camera (has_stream = True) và status = 'active'
        devices = db.query(Device).join(DeviceType).filter(
            DeviceType.has_stream == True,
            Device.status == 'active',
            Device.stream_url.isnot(None),
            Device.stream_url != ''
        ).all()
        
        logger.info(f"[Scheduler] Bắt đầu quét {len(devices)} camera...")
        
        for device in devices:
            try:
                logger.info(f"[Scheduler] Quét camera: {device.name} (ID: {device.device_id})")
                result = detect_from_camera_auto(db, device, num_images=3)
                
                if result.get('success'):
                    logger.info(f"[Scheduler] ✓ Camera {device.device_id}: {result.get('detections_count', 0)} detections")
                    if result.get('has_disease'):
                        logger.warning(f"[Scheduler] ⚠️ Camera {device.device_id}: Phát hiện bệnh!")
                else:
                    logger.error(f"[Scheduler] ✗ Camera {device.device_id}: {result.get('error', 'Unknown error')}")
            except Exception as e:
                logger.error(f"[Scheduler] Lỗi khi quét camera {device.device_id}: {e}", exc_info=True)
        
        logger.info(f"[Scheduler] Hoàn thành quét {len(devices)} camera")
    except Exception as e:
        logger.error(f"[Scheduler] Lỗi khi quét cameras: {e}", exc_info=True)
    finally:
        db.close()

# def start_scheduler():
#     """
#     Khởi động scheduler với 2 lần quét mỗi ngày:
#     - 8:00 sáng
#     - 18:00 chiều
#     """
#     if scheduler.running:
#         logger.warning("[Scheduler] Scheduler đã chạy rồi!")
#         return
    
#     # Thêm job quét vào 8:00 sáng mỗi ngày
#     scheduler.add_job(
#         scan_all_cameras,
#         trigger=CronTrigger(hour=8, minute=0),
#         id='morning_scan',
#         name='Quét camera buổi sáng (8:00)',
#         replace_existing=True
#     )
    
#     # Thêm job quét vào 18:00 chiều mỗi ngày
#     scheduler.add_job(
#         scan_all_cameras,
#         trigger=CronTrigger(hour=18, minute=0),
#         id='evening_scan',
#         name='Quét camera buổi chiều (18:00)',
#         replace_existing=True
#     )
    
#     scheduler.start()
#     logger.info("[Scheduler] Đã khởi động scheduler - Quét camera 2 lần/ngày (8:00 và 18:00)")

def start_scheduler():
    if scheduler.running:
        logger.warning("[Scheduler] Scheduler đã chạy rồi!")
        return

    # ✅ TEST: quét mỗi 15 giây
    scheduler.add_job(
        scan_all_cameras,
        trigger=IntervalTrigger(seconds=30),
        id='test_scan_every_15s',
        name='[TEST] Quét camera mỗi 15s',
        replace_existing=True,
        max_instances=1,
        coalesce=True
    )

    scheduler.start()
    logger.info("[Scheduler] Đã khởi động scheduler - TEST mỗi 15s")


    scheduler.start()
    logger.info("[Scheduler] Đã khởi động scheduler - TEST mỗi 1 phút")

def stop_scheduler():
    """
    Dừng scheduler
    """
    if scheduler.running:
        scheduler.shutdown()
        logger.info("[Scheduler] Đã dừng scheduler")

