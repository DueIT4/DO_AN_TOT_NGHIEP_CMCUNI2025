from typing import List, Optional

from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.models.device_type import DeviceType, DeviceTypeStatus
from app.schemas.device_type import (
    DeviceTypeCreate,
    DeviceTypeUpdate,
)


class DeviceTypeService:
    # Lấy tất cả loại thiết bị
    def list_device_types(self, db: Session) -> List[DeviceType]:
        return db.query(DeviceType).order_by(DeviceType.created_at.desc()).all()

    # Lấy chi tiết 1 loại thiết bị
    def get_device_type(self, db: Session, device_type_id: int) -> Optional[DeviceType]:
        return (
            db.query(DeviceType)
            .filter(DeviceType.device_type_id == device_type_id)
            .first()
        )

    # Tạo mới loại thiết bị
    def create_device_type(
        self, db: Session, body: DeviceTypeCreate
    ) -> DeviceType:
        dt = DeviceType(
            device_type_name=body.device_type_name,
            has_stream=body.has_stream,
            status=DeviceTypeStatus(body.status)
            if body.status
            else DeviceTypeStatus.active,
        )
        db.add(dt)
        db.commit()
        db.refresh(dt)
        return dt

    # Cập nhật loại thiết bị
    def update_device_type(
        self, db: Session, device_type_id: int, body: DeviceTypeUpdate
    ) -> Optional[DeviceType]:
        dt = self.get_device_type(db, device_type_id)
        if not dt:
            return None

        if body.device_type_name is not None:
            dt.device_type_name = body.device_type_name

        if body.has_stream is not None:
            dt.has_stream = body.has_stream

        if body.status is not None:
            dt.status = DeviceTypeStatus(body.status)

        db.commit()
        db.refresh(dt)
        return dt

    # Xoá loại thiết bị
    def delete_device_type(self, db: Session, device_type_id: int) -> bool:
        dt = self.get_device_type(db, device_type_id)
        if not dt:
            return False

        try:
            db.delete(dt)
            db.commit()
        except IntegrityError:
            db.rollback()
            # không xoá được do còn device tham chiếu
            raise
        return True


device_type_service = DeviceTypeService()
