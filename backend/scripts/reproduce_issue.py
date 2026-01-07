import sys
import os
from pathlib import Path

# Thêm thư mục gốc vào sys.path để import được app
sys.path.append(str(Path(__file__).parents[1]))

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings
from app.models.image_detection import Img, Detection
from app.models.users import Users
from app.models.devices import Device
from app.services.detect_service import save_detection_result
import datetime

def test_persistence():
    print(f"Connecting to DB: {settings.DATABASE_URL.split('@')[1]}") # Hide password
    engine = create_engine(settings.DATABASE_URL)
    SessionLocal = sessionmaker(bind=engine)
    db = SessionLocal()

    try:
        # 1. Get User and Device
        user = db.query(Users).first()
        if not user:
            print("❌ No users found in DB!")
            return
        
        device = db.query(Device).filter(Device.user_id == user.user_id).first()
        if not device:
            print(f"❌ No devices found for user {user.user_id}!")
            # Try finding ANY device
            device = db.query(Device).first()
            if device:
                print(f"⚠️ Using device {device.device_id} belonging to user {device.user_id} instead.")
                user = db.query(Users).get(device.user_id)
            else:
                 print("❌ No devices found at all!")
                 return

        print(f"✅ Found User: {user.user_id} ({user.email})")
        print(f"✅ Found Device: {device.device_id} ({device.name})")

        # 2. Simulate Auto Detection Data
        dummy_bytes = b"\xFF\xD8\xFF\xE0" + b"\x00" * 100 # Minimal fake JPEG header
        
        yolo_result = {
            "detections": [
                {"class_name": "Không xác định", "confidence": 0.8, "bbox": [0,0,100,100]}
            ],
            "num_detections": 1,
            "llm": {
                "disease_summary": "Test Summary from script",
                "care_instructions": "Test Instructions from script"
            }
        }

        print("\n--- ATTEMPTING SAVE_DETECTION_RESULT ---")
        try:
            result = save_detection_result(
                db=db,
                image_url=None, # Force upload
                raw=dummy_bytes,
                filename="test_script_reproduce.jpg",
                yolo_result=yolo_result,
                user_id=user.user_id,
                device_id=device.device_id,
                create_alert=True # Test notification logic too
            )
            print("✅ RESULT:", result)
            
            # Verify persistence
            print("\n--- VERIFYING PERSISTENCE ---")
            
            saved_det = db.query(Detection).filter(Detection.detection_id == result['detection_id']).first()
            if saved_det:
                print(f"✅ Detection {saved_det.detection_id} found in DB.")
                print(f"   - DiseaseID: {saved_det.disease_id}")
                print(f"   - Description: {saved_det.description}")
            else:
                print("❌ Detection NOT found in DB immediately after save!")

        except Exception as e:
            print("\n❌❌❌ EXCEPTION DURING SAVE ❌❌❌")
            print(e)
            import traceback
            traceback.print_exc()

    finally:
        db.close()

if __name__ == "__main__":
    test_persistence()
