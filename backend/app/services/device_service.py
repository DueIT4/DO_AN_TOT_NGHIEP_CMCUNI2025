# app/services/device_service.py
from typing import List
from sqlalchemy.orm import Session
from sqlalchemy import select

from app.models.devices import Device
from app.schemas.devices import DeviceCreate, DeviceUpdate


class DeviceService:
    def list_devices(self, db: Session) -> List[Device]:
        return db.scalars(select(Device)).all()

    def get_device(self, db: Session, device_id: int) -> Device | None:
        return db.get(Device, device_id)

    def create_device(self, db: Session, data: DeviceCreate, user_id: int | None) -> Device:
        # 🔹 Phòng trường hợp client vẫn gửi 0
        parent_id = data.parent_device_id
        if parent_id == 0:
            parent_id = None

        device = Device(
            user_id=user_id,
            name=data.name,
            device_type_id=data.device_type_id,
            parent_device_id=parent_id,
            serial_no=data.serial_no,
            location=data.location,
            status=data.status or "active",
            stream_url=data.stream_url,
        )
        db.add(device)
        db.commit()
        db.refresh(device)
        return device

    def update_device(self, db: Session, device_id: int, data: DeviceUpdate) -> Device:
        device = self.get_device(db, device_id)
        if not device:
            raise LookupError("Thiết bị không tồn tại")

        update_data = data.dict(exclude_unset=True)

        # 🔹 Nếu có gửi parent_device_id và nó = 0 → đổi thành None
        if "parent_device_id" in update_data and update_data["parent_device_id"] == 0:
            update_data["parent_device_id"] = None

        for field, value in update_data.items():
            setattr(device, field, value)

        db.commit()
        db.refresh(device)
        return device

    def delete_device(self, db: Session, device_id: int) -> None:
        device = self.get_device(db, device_id)
        if not device:
            raise LookupError("Thiết bị không tồn tại")
        db.delete(device)
        db.commit()


devices_service = DeviceService()
