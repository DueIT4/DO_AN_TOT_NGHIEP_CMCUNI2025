# app/api/v1/routes_sensors.py
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime

from app.core.database import get_db

from app.schemas.sensor import SensorInput
from app.models.sensor_readings import SensorReadings
from app.models.devices import Device
from app.models.device_logs import DeviceLogs
from app.models.notification import Notifications

router = APIRouter(tags=["Sensors"])

# ID admin hệ thống (bạn đã seed admin user_id = 1 trong SQL)
SYSTEM_ADMIN_ID = 1


@router.post("/")
def add_sensor_reading(payload: SensorInput, db: Session = Depends(get_db)):
    """
    Endpoint cho thiết bị thật gọi về:
    - Lưu dữ liệu cảm biến
    - Ghi log thiết bị (event_type = 'online')
    - Nếu bất thường -> tạo notification cho nông dân
    """
    # 1) Kiểm tra device tồn tại
    device = db.get(Device, payload.device_id)
    if not device:
        raise HTTPException(status_code=404, detail="Thiết bị không tồn tại")

    # 2) Lưu sensor_readings
    reading = SensorReadings(
        device_id=payload.device_id,
        metric=payload.metric,
        value_num=payload.value_num,
        unit=payload.unit,
        recorded_at=datetime.utcnow(),
    )
    db.add(reading)
    db.flush()

    # 3) Ghi log thiết bị: mỗi lần gửi data coi như thiết bị đang online
    log = DeviceLogs(
        device_id=device.device_id,
        event_type="online",
        description=f"Nhận dữ liệu {payload.metric} = {payload.value_num}{payload.unit}",
    )
    db.add(log)

    # 4) Rule cảnh báo đơn giản -> notifications cho nông dân
    # Chỉ tạo nếu device gắn với 1 user cụ thể
    if device.user_id is not None:
        should_warn = False
        title = ""
        description = ""

        # Ví dụ rule: soil_moisture < 30% => đất khô
        if payload.metric == "soil_moisture" and payload.value_num < 30:
            should_warn = True
            title = "Cảnh báo độ ẩm đất thấp"
            description = (
                f"Độ ẩm đất hiện tại là {payload.value_num}{payload.unit} "
                f"tại thiết bị '{device.name or device.device_id}'"
                + (f" ở vị trí {device.location}" if device.location else "")
                + ". Vui lòng kiểm tra và tưới thêm nước cho cây."
            )

        # Bạn có thể thêm nhiều rule khác tại đây
        # if payload.metric == "temperature" and payload.value_num > 40: ...

        if should_warn:
            notif = Notifications(
                user_id=device.user_id,           # nông dân nhận
                sender_id=SYSTEM_ADMIN_ID,        # admin/hệ thống gửi
                title=title,
                description=description,
            )
            db.add(notif)

    db.commit()

    return {
        "message": "Đã ghi dữ liệu cảm biến",
        "device_id": device.device_id,
        "reading_id": reading.reading_id,
        "log_id": log.log_id,
    }
