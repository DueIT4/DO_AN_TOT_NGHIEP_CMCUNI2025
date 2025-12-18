# app/services/device_service.py
from __future__ import annotations

from typing import List, Optional, Dict, Any
from sqlalchemy.orm import Session
from sqlalchemy import select, or_

from app.models.devices import Device
from app.models.device_type import DeviceType
from app.models.image_detection import Detection, Img, Disease
from app.schemas.devices import DeviceCreate, DeviceUpdate


class DeviceService:
    # =========================
    # ADMIN: list all devices
    # =========================
    def list_devices(self, db: Session) -> List[Device]:
        return db.scalars(select(Device)).all()

    # =========================
    # COMMON: get device by id
    # =========================
    def get_device(self, db: Session, device_id: int) -> Device | None:
        return db.get(Device, device_id)

    # =========================
    # USER: list devices of a user (with optional search)
    # =========================
    def list_devices_of_user(
        self,
        db: Session,
        user_id: int,
        q: Optional[str] = None,
    ) -> List[Device]:
        qs = db.query(Device).filter(Device.user_id == user_id)

        if q:
            like = f"%{q}%"
            qs = qs.filter(
                or_(
                    Device.name.ilike(like),
                    Device.location.ilike(like),
                )
            )

        return qs.order_by(Device.device_id.desc()).all()

    # =========================
    # CREATE
    # =========================
    def create_device(self, db: Session, data: DeviceCreate, user_id: int | None) -> Device:
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

    # =========================
    # UPDATE
    # =========================
    def update_device(self, db: Session, device_id: int, data: DeviceUpdate) -> Device | None:
        device = self.get_device(db, device_id)
        if not device:
            return None

        update_data = data.dict(exclude_unset=True)

        if "parent_device_id" in update_data and update_data["parent_device_id"] == 0:
            update_data["parent_device_id"] = None

        for field, value in update_data.items():
            setattr(device, field, value)

        db.commit()
        db.refresh(device)
        return device

    # =========================
    # DELETE
    # =========================
    def delete_device(self, db: Session, device_id: int) -> bool:
        device = self.get_device(db, device_id)
        if not device:
            return False
        db.delete(device)
        db.commit()
        return True

    # =========================
    # USER: latest detection for a device (router sẽ check ownership)
    # =========================
    def get_latest_detection_payload(
        self,
        db: Session,
        device_id: int,
    ) -> Dict[str, Any]:
        row = (
            db.query(Detection, Img, Disease)
            .join(Img, Detection.img_id == Img.img_id)
            .join(Disease, Detection.disease_id == Disease.disease_id, isouter=True)
            .filter(Img.device_id == device_id)
            .order_by(Detection.created_at.desc())
            .first()
        )

        if not row:
            return {"found": False}

        det, img_row, disease = row
        name = disease.name if disease and disease.name else "Không xác định"
        conf = float(det.confidence or 0.0) / 100.0

        return {
            "found": True,
            "detection_id": det.detection_id,
            "disease_name": name,
            "confidence": conf,
            "img_url": img_row.file_url,
            "created_at": det.created_at,
        }

    # =========================
    # USER: select camera (router sẽ check ownership)
    # =========================
    def select_camera_for_user(
        self,
        db: Session,
        user_id: int,
        device: Device,
    ) -> Device:
        # check device is a camera (has_stream)
        dt = db.get(DeviceType, device.device_type_id)
        if not dt or not dt.has_stream:
            raise ValueError("Device is not a camera")

        # set inactive all cameras of user
        db.query(Device).filter(
            Device.user_id == user_id,
            Device.device_type.has(DeviceType.has_stream == True),
        ).update({Device.status: "inactive"}, synchronize_session=False)

        # set active selected one
        device.status = "active"
        db.commit()
        db.refresh(device)
        return device


devices_service = DeviceService()
