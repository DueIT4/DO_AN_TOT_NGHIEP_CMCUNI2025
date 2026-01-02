# backend/app/services/inference_service.py
import os
from io import BytesIO
from typing import List, Dict, Any
from pathlib import Path  # Nên dùng Pathlib cho chuyên nghiệp

from ultralytics import YOLO
from PIL import Image

# 1. Xác định đường dẫn gốc của thư mục 'app'
# File này ở: backend/app/services/inference_service.py
# .parent -> services/
# .parent.parent -> app/
APP_ROOT = Path(__file__).resolve().parent.parent

# 2. Cấu hình đường dẫn Model
# Nếu bạn đã copy best.pt vào backend/app/weights/best.pt
DEFAULT_MODEL_PATH = str(APP_ROOT / "weights" / "best.pt")

MODEL_PATH = os.getenv("MODEL_PATH", DEFAULT_MODEL_PATH)
# 🔹 Map nhãn YOLO -> tên tiếng Việt
VN_LABELS = {
    "pomelo_leaf_healthy": "Lá bưởi khỏe mạnh",
    "pomelo_leaf_miner": "Lá bưởi bị sâu vẽ bùa",
    "pomelo_leaf_yellowing": "Lá bưởi bị vàng lá",
    "pomelo_fruit_healthy": "Quả bưởi khỏe mạnh",
    "pomelo_fruit_scorch": "Quả bưởi bị cháy / nám vỏ",
    "unknown": "Không xác định",
}


class YoloDetector:
    def __init__(self, model_path: str = MODEL_PATH):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Model not found: {model_path}")

        self.model = YOLO(model_path)    # YOLO sẽ tự xử lý toàn bộ ảnh
        self.names = self.model.names    # id -> class_name

    def predict_bytes(
        self,
        raw_bytes: bytes,
        conf: float = 0.5,
        iou: float = 0.5,
    ) -> Dict[str, Any]:
        """Predict + tự tạo giải thích nếu không phát hiện được bệnh"""

        img = Image.open(BytesIO(raw_bytes)).convert("RGB")

        results = self.model.predict(
            img,
            conf=conf,
            iou=iou,
            imgsz=640,
            verbose=False,
        )

        detections: List[Dict[str, Any]] = []
        if not results:
            # trường hợp YOLO không trả output
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

            class_key = self.names.get(cls_id, str(cls_id))
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
            "explanation": None  # Có bệnh → Không cần giải thích lỗi
        }

    # ============================================
    # 🔥 Hàm sinh giải thích khi không phát hiện được bệnh
    # ============================================
    def _no_detection_explanation(self) -> Dict[str, Any]:
        return {
            "num_detections": 0,
            "detections": [],
            "explanation": (
                "Hệ thống không phát hiện được triệu chứng bệnh rõ ràng trên hình ảnh.\n"
                "\n"
                "📌 **Có thể do một trong các nguyên nhân sau:**\n"
                "• Lá hoặc quả đang khỏe mạnh.\n"
                "• Ảnh chụp quá xa, vùng bệnh quá nhỏ để AI nhận diện.\n"
                "• Ảnh bị mờ, thiếu sáng hoặc bị nén (ảnh JPEG nén mạnh).\n"
                "• Ảnh screenshot (không phải ảnh gốc từ camera).\n"
                "• Bệnh không nằm trong các nhóm bệnh mà mô hình đã được huấn luyện.\n"
                "\n"
                "👉 **Gợi ý để hệ thống nhận diện chính xác hơn:**\n"
                "• Chụp gần vùng nghi là có bệnh (cách 15–25 cm).\n"
                "• Chụp trong điều kiện đủ sáng, không rung tay.\n"
                "• Tránh để nhiều lá/đối tượng khác trong ảnh.\n"
                "• Dùng ảnh gốc từ camera, không chụp lại màn hình.\n"
                "\n"
                "Bạn có thể thử chụp lại và gửi ảnh mới để hệ thống phân tích chính xác hơn."
            )
        }


# instance dùng chung
detector: YoloDetector | None = None
try:
    detector = YoloDetector(MODEL_PATH)
except FileNotFoundError:
    detector = None
