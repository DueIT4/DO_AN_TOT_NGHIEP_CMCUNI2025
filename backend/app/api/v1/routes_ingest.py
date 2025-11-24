from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from datetime import datetime, timezone
from typing import List, Optional

from pydantic import BaseModel, Field
from app.core.db import get_db
from app.models.devices import Device
from app.models.device_logs import DeviceLogs, EventType
from app.models.sensor_readings import SensorReadings  # bạn đã có model này

router = APIRouter(tags=["Ingest"])

# ====== Schemas ======
class ReadingIn(BaseModel):
    metric: str
    value_num: float
    unit: str
    recorded_at: Optional[datetime] = None  # nếu thiếu sẽ dùng ts của payload

class IngestPayload(BaseModel):
    serial_no: str = Field(..., description="Serial của thiết bị/gateway")
    device_id: Optional[int] = Field(None, description="Nếu biết device_id thì gửi kèm")
    ts: Optional[datetime] = Field(None, description="Thời điểm mẫu (UTC). Mặc định now()")
    readings: List[ReadingIn]
    # Có thể bổ sung trường metadata khác nếu cần

# ====== Helpers ======
def _find_device(db: Session, device_id: Optional[int], serial_no: str) -> Optional[Device]:
    if device_id:
        dev = db.get(Device, device_id)
        if dev:
            return dev
    return db.query(Device).filter(Device.serial_no == serial_no).first()

def _verify_device_token(device: Device, token: Optional[str]) -> bool:
    """
    TODO: thêm cột device_token vào bảng devices và so sánh:
      return token is not None and token == device.device_token
    Tạm thời bỏ qua xác thực nếu token trống (để test nhanh).
    """
    return True if token else True

def _evaluate_rules(readings: List[ReadingIn]) -> list[tuple[str, str]]:
    """
    Luật cảnh báo đơn giản mẫu.
    Trả về danh sách (title, message). Tùy metric bạn mở rộng thêm.
    """
    alerts: list[tuple[str, str]] = []
    for r in readings:
        if r.metric == "soil_moisture" and r.value_num < 20:
            alerts.append(("Độ ẩm đất thấp", f"{r.value_num}% < 20% — nên tưới nhẹ 5–10 phút"))
        if r.metric == "air_temp" and r.value_num > 40:
            alerts.append(("Nhiệt độ cao", f"{r.value_num}°C > 40°C — kiểm tra che nắng/tưới phun sương"))
    return alerts

# ====== Endpoint ======
@router.post("/sensors", summary="Nhận dữ liệu cảm biến từ gateway/cảm biến")
def ingest_sensors(
    data: IngestPayload,
    db: Session = Depends(get_db),
    x_device_token: Optional[str] = Header(None, convert_underscores=True),
):
    # 1) Tìm thiết bị theo device_id hoặc serial_no
    device = _find_device(db, data.device_id, data.serial_no)
    if not device:
        raise HTTPException(status_code=404, detail="Thiết bị không tồn tại")

    # 2) Xác thực token (nếu đã bật)
    if not _verify_device_token(device, x_device_token):
        raise HTTPException(status_code=401, detail="Token sai hoặc thiếu")

    # 3) Ghi readings
    base_ts = data.ts or datetime.now(timezone.utc)
    inserted = 0
    for r in data.readings:
        recorded_at = r.recorded_at or base_ts
        db.add(SensorReadings(
            device_id=device.device_id,
            metric=r.metric,
            value_num=r.value_num,
            unit=r.unit,
            recorded_at=recorded_at
        ))
        inserted += 1
    db.commit()

    # 4) Chạy luật cảnh báo đơn giản → lưu log (và có thể bắn push)
    alerts = _evaluate_rules(data.readings)
    for title, msg in alerts:
        db.add(DeviceLogs(
            device_id=device.device_id,
            event_type=EventType.error,  # hoặc maintenance tùy loại cảnh báo
            description=f"[ALERT] {title}: {msg}"
        ))
    if alerts:
        db.commit()
        # TODO: push FCM/SMS cho chủ thiết bị (device.user_id → users.fcm_token)

    return {"ok": True, "device_id": device.device_id, "inserted": inserted, "alerts": len(alerts)}
