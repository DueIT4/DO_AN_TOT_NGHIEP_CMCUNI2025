from sqlalchemy.orm import Session
from fastapi import HTTPException, status
from datetime import datetime
from app.models.devices import Devices, DeviceState
from app.models.device_logs import DeviceLogs
from app.models.device_type import DeviceType
from app.services.common import get_or_404, commit_refresh, paginate


class DeviceService:
    """💡 Service layer xử lý nghiệp vụ cho bảng devices"""

    # -----------------------------
    # Lấy danh sách thiết bị
    # -----------------------------
    def list(self, db: Session, page: int = 1, size: int = 20):
        q = db.query(Devices).order_by(Devices.created_at.desc())
        return paginate(q, page, size)

    # -----------------------------
    # Lấy chi tiết thiết bị
    # -----------------------------
    def get(self, db: Session, device_id: int):
        return get_or_404(db, Devices, device_id)

    # -----------------------------
    # Tạo mới thiết bị
    # -----------------------------
    def create(self, db: Session, data: dict):
        # Kiểm tra trùng serial
        if db.query(Devices).filter(Devices.serial_no == data["serial_no"]).first():
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Serial đã tồn tại",
            )
        device = Devices(**data)
        return commit_refresh(db, device)

    # -----------------------------
    # Cập nhật thiết bị
    # -----------------------------
    def update(self, db: Session, device_id: int, data: dict):
        device = get_or_404(db, Devices, device_id)
        for key, value in data.items():
            if hasattr(device, key):
                setattr(device, key, value)
        return commit_refresh(db, device)

    # -----------------------------
    # Xoá thiết bị
    # -----------------------------
    def delete(self, db: Session, device_id: int):
        device = get_or_404(db, Devices, device_id)
        db.delete(device)
        db.commit()
        return {"message": f"Đã xoá thiết bị ID={device_id}"}

    # -----------------------------
    # Ghi log sự kiện thiết bị
    # -----------------------------
    def add_log(self, db: Session, device_id: int, event_type: str, description: str):
        get_or_404(db, Devices, device_id)
        log = DeviceLogs(
            device_id=device_id,
            event_type=event_type,
            description=description,
            created_at=datetime.utcnow(),
        )
        return commit_refresh(db, log)


# ✅ Khởi tạo instance dùng chung
devices_service = DeviceService()
