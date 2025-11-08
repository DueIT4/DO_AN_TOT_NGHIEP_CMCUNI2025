from pathlib import Path
from io import BytesIO
from typing import Dict, Any
from PIL import Image
from fastapi import UploadFile, HTTPException
from app.models.onnx_detector import OnnxDetector

# Tính đường dẫn model từ root của project
# File này ở: backend/app/services/inference_service.py
# parents[0] = services, [1] = app, [2] = backend, [3] = root
REPO_ROOT = Path(__file__).resolve().parents[3]
MODEL_PATH = REPO_ROOT / "ml" / "exports" / "v1.0" / "best.onnx"
LABELS_PATH = REPO_ROOT / "ml" / "exports" / "v1.0" / "labels.txt"

class InferenceService:
    def __init__(self):
        """Khởi tạo service với ONNX detector."""
        # Log đường dẫn để debug
        import logging
        logger = logging.getLogger(__name__)
        logger.info(f"Looking for model at: {MODEL_PATH}")
        logger.info(f"Looking for labels at: {LABELS_PATH}")
        
        if not MODEL_PATH.exists():
            raise FileNotFoundError(
                f"Model file not found: {MODEL_PATH}\n"
                f"Please ensure the ONNX model file exists at: ml/exports/v1.0/best.onnx"
            )
        if not LABELS_PATH.exists():
            raise FileNotFoundError(
                f"Labels file not found: {LABELS_PATH}\n"
                f"Please ensure labels.txt exists at: ml/exports/v1.0/labels.txt"
            )
        
        self.detector = OnnxDetector(
            model_path=str(MODEL_PATH),
            labels_path=str(LABELS_PATH),
            input_size=(640, 640)
        )
        self.model_version = "v1.0"
    
    async def analyze(self, image: UploadFile) -> Dict[str, Any]:
        """
        Phân tích ảnh và trả về kết quả dự đoán.
        
        Args:
            image: File ảnh upload từ client
            
        Returns:
            Dict chứa:
                - disease: tên bệnh
                - confidence: độ chính xác (0-1)
                - model_version: phiên bản model
        """
        # Kiểm tra định dạng file
        if not image.content_type or not image.content_type.startswith("image/"):
            raise HTTPException(status_code=400, detail="File phải là ảnh")
        
        try:
            # Đọc dữ liệu ảnh
            image_data = await image.read()
            if len(image_data) == 0:
                raise HTTPException(status_code=400, detail="File ảnh rỗng")
            
            # Mở ảnh bằng PIL
            img = Image.open(BytesIO(image_data))
            img = img.convert("RGB")  # Đảm bảo là RGB
            
            # Chạy inference
            result = self.detector.predict(img)
            
            # Trả về kết quả
            return {
                "disease": result.get("label", "Không xác định"),
                "confidence": float(result.get("confidence", 0.0)),
                "model_version": self.model_version
            }
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Lỗi khi phân tích ảnh: {str(e)}")

