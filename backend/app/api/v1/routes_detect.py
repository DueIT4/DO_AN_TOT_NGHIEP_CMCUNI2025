from fastapi import APIRouter, UploadFile, File, HTTPException
from io import BytesIO
from PIL import Image, UnidentifiedImageError
from app.services.inference_service import OnnxDetector
import os
from pathlib import Path

router = APIRouter()

# Resolve repo root from this file location to be robust to CWD
THIS_DIR = Path(__file__).resolve().parent  # .../backend/app/api/v1
REPO_ROOT = THIS_DIR.parents[3]             # go up to repo root

# Defaults relative to repo root; allow env overrides
MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml/exports/v1.0/best.onnx"))
LABELS_PATH = os.getenv("LABELS_PATH", str(REPO_ROOT / "ml/exports/v1.0/labels.txt"))

try:
    detector = OnnxDetector(model_path=MODEL_PATH, labels_path=LABELS_PATH)
except FileNotFoundError:
    detector = None

@router.post("/detect")
async def detect(image: UploadFile = File(...)):
    if detector is None:
        raise HTTPException(status_code=500, detail=f"Model not available: {MODEL_PATH}")
    try:
        data = await image.read()
        img = Image.open(BytesIO(data))
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Invalid image file")
    try:
        result = detector.infer_top1(img)
        return result
    except Exception as e:
        # Surface inference issues clearly to client for debugging
        raise HTTPException(status_code=500, detail=f"Inference error: {e}")
