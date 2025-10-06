# backend/app/api/v1/routes_detect.py
from pathlib import Path
from fastapi import APIRouter, UploadFile, File
from io import BytesIO
from PIL import Image
from backend.app.services.inference_service import OnnxDetector

router = APIRouter()

# Tính đường dẫn GỐC REPO từ vị trí file này
# parents[0]=.../v1 , [1]=.../api , [2]=.../app , [3]=.../backend , [4]=<REPO_ROOT>
REPO_ROOT = Path(__file__).resolve().parents[4]

MODEL_PATH  = REPO_ROOT / "ml" / "exports" / "v1.0" / "best.onnx"    # hoặc "model.onnx" nếu bạn đổi tên
LABELS_PATH = REPO_ROOT / "ml" / "exports" / "v1.0" / "labels.txt"

# (tuỳ chọn) log để debug
print("MODEL_PATH:", MODEL_PATH)
print("LABELS_PATH:", LABELS_PATH)

detector = OnnxDetector(
    model_path=str(MODEL_PATH),
    labels_path=str(LABELS_PATH),
    imgsz=640
)

@router.post("/detect")
async def detect(image: UploadFile = File(...)):
    data = await image.read()
    img = Image.open(BytesIO(data))
    return detector.infer_top1(img)
