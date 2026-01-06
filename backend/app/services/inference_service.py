# backend/app/services/inference_service.py
import os
from io import BytesIO
from typing import List, Dict, Any
from pathlib import Path

from ultralytics import YOLO
from PIL import Image

# 1. Xác định đường dẫn gốc
APP_ROOT = Path(__file__).resolve().parent.parent

# 2. Cấu hình đường dẫn Model & Labels
DEFAULT_MODEL_PATH = str(APP_ROOT / "weights" / "best.pt")
LABEL_PATH = str(APP_ROOT / "weights" / "labels.txt")

MODEL_PATH = os.getenv("MODEL_PATH", DEFAULT_MODEL_PATH)

# 🔹 Map nhãn YOLO -> tên tiếng Việt
VN_LABELS = {
    "pomelo_leaf_healthy": "Lá bưởi khỏe mạnh",
    "pomelo_leaf_miner": "Lá bưởi bị sâu vẽ bùa",
    "pomelo_leaf_yellowing": "Lá bưởi bị vàng lá",
    "pomelo_fruit_healthy": "Quả bưởi khỏe mạnh",
    "pomelo_fruit_scorch": "Quả bưởi bị cháy / nám vỏ",
}

class YoloDetector:
    def __init__(self, model_path: str = MODEL_PATH, label_path: str = LABEL_PATH):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found: {model_path}")

        self.model = YOLO(model_path)
        
        # 🟢 Load Labels from file if exists (User Request)
        self.class_names = []
        if os.path.exists(label_path):
            try:
                with open(label_path, "r", encoding="utf-8") as f:
                    self.class_names = [line.strip() for line in f.readlines() if line.strip()]
                print(f"✅ Loaded {len(self.class_names)} labels from {label_path}")
            except Exception as e:
                print(f"⚠️ Error loading labels.txt: {e}")
                self.class_names = []
        
        # Fallback to model names if file empty/missing
        if not self.class_names:
            self.class_names = self.model.names

    def predict_bytes(
        self,
        raw_bytes: bytes,
        conf: float = 0.5,
        iou: float = 0.5,
    ) -> Dict[str, Any]:
        """Predict + tự tạo giải thích nếu không phát hiện được bệnh"""
        
        try:
            img = Image.open(BytesIO(raw_bytes)).convert("RGB")
        except Exception:
            # Nếu bytes lỗi
            return self._no_detection_explanation()

        results = self.model.predict(
            img,
            conf=conf,
            iou=iou,
            imgsz=640,
            verbose=False,
        )

        detections: List[Dict[str, Any]] = []
        
        if not results:
            return self._no_detection_explanation()

        r = results[0]
        h, w = r.orig_shape

        # ----- Nếu không detect được bệnh -----
        if r.boxes is None or len(r.boxes) == 0:
            return self._no_detection_explanation()

        # ----- Có detect → trả đầy đủ -----
        for box in r.boxes:
            cls_id = int(box.cls[0].item())
            conf_val = float(box.conf[0].item())
            x1, y1, x2, y2 = box.xyxy[0].tolist()

            # ✅ FIX: Lookup Safely using loaded class_names list/dict
            # self.class_names could be a list or dict depending on source
            class_key = "unknown"
            
            if isinstance(self.class_names, list) and 0 <= cls_id < len(self.class_names):
                class_key = self.class_names[cls_id]
            elif isinstance(self.class_names, dict) and cls_id in self.class_names:
                class_key = self.class_names[cls_id]
            else:
                class_key = str(cls_id)

            # Map to Vietnamese
            class_vi = VN_LABELS.get(class_key, class_key)

            detections.append({
                "class_id": cls_id,
                "class_key": class_key,
                "class_name": class_vi,
                "confidence": round(conf_val, 4),
                "bbox": [float(x1), float(y1), float(x2), float(y2)],
                "image_width": w,
                "image_height": h,
            })

        return {
            "num_detections": len(detections),
            "detections": detections,
            "explanation": None
        }

    def _no_detection_explanation(self) -> Dict[str, Any]:
        return {
            "num_detections": 0,
            "detections": [],
            "explanation": (
                "Hệ thống không phát hiện được triệu chứng bệnh rõ ràng trên hình ảnh.\n"
                "\n"
                "📌 **Có thể do:** Lá/quả khỏe mạnh, ảnh mờ, hoặc chụp quá xa.\n"
                "👉 **Gợi ý:** Chụp gần (15-25cm), đủ sáng, rõ nét."
            )
        }

# ============================================
# 🔥 Khởi tạo instance dùng chung
# ============================================
detector: YoloDetector | None = None

print(f"--- Init Detector ---")
try:
    detector = YoloDetector(MODEL_PATH)
    print("🚀 YOLO Detector Ready!")
except Exception as e:
    print(f"❌ Error init detector: {e}")
    detector = None
