"""
Scheduler để tự động quét ảnh từ camera mỗi 30 giây và cleanup HLS sessions
"""
from apscheduler.triggers.interval import IntervalTrigger
from apscheduler.schedulers.background import BackgroundScheduler
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
    Thu thập 1 ảnh từ mỗi camera và phân tích bằng AI
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
                # ✅ OPTIMIZED: Thu thập 1 ảnh và phân tích, KHÔNG stop stream đang được dùng
                # auto_stop_stream=False để không làm gián đoạn video đang xem
                result = detect_from_camera_auto(db, device, num_images=1, auto_stop_stream=False)
                
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


def cleanup_hls_sessions():
    """
    Cleanup các HLS session cũ và orphaned ffmpeg processes
    """
    try:
        from app.services.hls_cleanup_service import cleanup_all
        result = cleanup_all()
        if result['sessions_cleaned'] > 0 or result['processes_killed'] > 0:
            logger.info(
                f"[HLS Cleanup] Cleaned {result['sessions_cleaned']} sessions, "
                f"killed {result['processes_killed']} orphaned processes"
            )
    except Exception as e:
        logger.error(f"[HLS Cleanup] Failed: {e}", exc_info=True)


def check_sensor_alerts():
    """
    Kiểm tra cảnh báo sensor (nhiệt độ, độ ẩm) và tạo notification
    """
    db: Session = SessionLocal()
    try:
        from app.services.sensor_alert_service import check_sensor_alerts
        result = check_sensor_alerts(db, hours_back=1)
        if result['alerts_created'] > 0:
            logger.info(
                f"[Sensor Alert] Đã tạo {result['alerts_created']} cảnh báo "
                f"từ {result['readings_analyzed']} sensor readings"
            )
    except Exception as e:
        logger.error(f"[Sensor Alert] Failed: {e}", exc_info=True)
    finally:
        db.close()


def start_scheduler():
    """
    Khởi động scheduler với thu thập ảnh mỗi 30 giây và cleanup HLS mỗi 10 phút
    """
    if scheduler.running:
        logger.warning("[Scheduler] Scheduler đã chạy rồi!")
        return

    # Thu thập ảnh từ camera mỗi 30 giây
    scheduler.add_job(
        scan_all_cameras,
        trigger=IntervalTrigger(seconds=30),
        id='auto_scan_every_30s',
        name='Thu thập ảnh từ camera mỗi 30 giây',
        replace_existing=True,
        max_instances=1,
        coalesce=True,
        misfire_grace_time=15,
    )
    
    # ✅ NEW: Cleanup HLS sessions mỗi 10 phút
    scheduler.add_job(
        cleanup_hls_sessions,
        trigger=IntervalTrigger(minutes=10),
        id='cleanup_hls_every_10min',
        name='Cleanup HLS sessions mỗi 10 phút',
        replace_existing=True,
        max_instances=1,
        coalesce=True,
    )
    
    # ✅ NEW: Kiểm tra cảnh báo sensor mỗi 30 giây
    scheduler.add_job(
        check_sensor_alerts,
        trigger=IntervalTrigger(seconds=30),
        id='check_sensor_alerts_every_30s',
        name='Kiểm tra cảnh báo sensor mỗi 30 giây',
        replace_existing=True,
        max_instances=1,
        coalesce=True,
    )

    scheduler.start()
    logger.info("[Scheduler] Đã khởi động scheduler:")
    logger.info("  - Thu thập ảnh từ camera mỗi 30 giây")
    logger.info("  - Cleanup HLS sessions mỗi 10 phút")
    logger.info("  - Kiểm tra cảnh báo sensor mỗi 30 giây")

def stop_scheduler():
    """
    Dừng scheduler
    """
    if scheduler.running:
        scheduler.shutdown()
        logger.info("[Scheduler] Đã dừng scheduler")

