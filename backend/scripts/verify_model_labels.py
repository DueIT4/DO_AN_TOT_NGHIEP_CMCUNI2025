import os
import sys
from pathlib import Path
from ultralytics import YOLO

# Setup paths
APP_ROOT = Path("backend/app").resolve()
MODEL_PATH = APP_ROOT / "weights/best.pt"

if not MODEL_PATH.exists():
    # Try finding it relative to current working dir if script is run from root
    MODEL_PATH = Path("backend/app/weights/best.pt").resolve()

print(f"Checking model at: {MODEL_PATH}")

if not MODEL_PATH.exists():
    print(f"Error: Model file not found at {MODEL_PATH}")
    sys.exit(1)

try:
    model = YOLO(MODEL_PATH)
    print("\nModel Class Names:")
    for id, name in model.names.items():
        print(f"  ID {id}: {name}")

    print("\nVN_LABELS Mapping in Code (inference_service.py):")
    VN_LABELS = {
        "pomelo_leaf_healthy": "Lá bưởi khỏe mạnh",
        "pomelo_leaf_miner": "Lá bưởi bị sâu vẽ bùa",
        "pomelo_leaf_yellowing": "Lá bưởi bị vàng lá",
        "pomelo_fruit_healthy": "Quả bưởi khỏe mạnh",
        "pomelo_fruit_scorch": "Quả bưởi bị cháy / nám vỏ",
    }
    
    print("\n---- Verification ----")
    for id, name in model.names.items():
        if name in VN_LABELS:
            print(f"✅ Class '{name}' maps to '{VN_LABELS[name]}'")
        else:
            print(f"⚠️ Class '{name}' NOT FOUND in VN_LABELS!")

except Exception as e:
    print(f"Error loading model: {e}")
