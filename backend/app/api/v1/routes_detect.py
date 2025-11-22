# backend/app/api/v1/routes_detect.py
from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import JSONResponse
from io import BytesIO
from PIL import Image, UnidentifiedImageError
from app.services.inference_service import OnnxDetector
import os
from pathlib import Path
import numpy as np

router = APIRouter()

THIS_DIR = Path(__file__).resolve().parent
REPO_ROOT = THIS_DIR.parents[3]
MODEL_PATH = os.getenv("MODEL_PATH", str(REPO_ROOT / "ml" / "exports" / "v1.0" / "best.onnx"))
LABELS_PATH = os.getenv("LABELS_PATH", str(REPO_ROOT / "ml" / "exports" / "v1.0" / "labels.txt"))

try:
    detector = OnnxDetector(model_path=MODEL_PATH, labels_path=LABELS_PATH)
except FileNotFoundError:
    detector = None

def to_jsonable(obj):
    if obj is None or isinstance(obj, (str, int, float, bool)):
        return obj
    if isinstance(obj, np.generic):
        return obj.item()
    if isinstance(obj, (list, tuple)):
        return [to_jsonable(x) for x in obj]
    if isinstance(obj, dict):
        return {str(k): to_jsonable(v) for k, v in obj.items()}
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    return str(obj)

def normalize_result(raw):
    """Ép mọi output model về dict có keys ổn định."""
    j = to_jsonable(raw)
    if isinstance(j, dict):
        # Nếu model đã trả đủ khóa → giữ nguyên
        disease = j.get("disease")
        confidence = j.get("confidence")
        llm = j.get("llm_explanation")
        boxes = j.get("boxes")
        # Nếu thiếu, vẫn gói lại dưới 'payload'
        if disease is not None or confidence is not None or llm is not None or boxes is not None:
            return j
        return {"payload": j}
    if isinstance(j, list):
        return {"items": j}
    # string/number/khác
    return {"payload": j}

@router.post("/detect")
async def detect(image: UploadFile = File(...)):
    if detector is None:
        raise HTTPException(status_code=500, detail=f"Model not available: {MODEL_PATH}")

    try:
        data = await image.read()
        img = Image.open(BytesIO(data)).convert("RGB")
    except UnidentifiedImageError:
        raise HTTPException(status_code=400, detail="Invalid image file")

    try:
        raw = detector.infer_top1(img)  # có thể trả dict/list/str/…
        data_norm = normalize_result(raw)
        payload = {"success": True, "message": "ok", "data": data_norm}
        return JSONResponse(content=payload, status_code=200)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Inference error: {e}")
