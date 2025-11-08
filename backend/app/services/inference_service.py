# app/services/inference_service.py
import io
import os
from typing import Dict, Any, Optional

import numpy as np
from fastapi import UploadFile, HTTPException
from PIL import Image, ImageOps, ImageFilter

from app.models.onnx_detector import OnnxDetector
from app.services.llm_service import explain_disease_with_llm
from app.utils.logger import logger

# ====== ĐƯỜNG DẪN MODEL/LABELS (chuẩn hoá để không lệch thư mục) ======
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.normpath(os.path.join(BASE_DIR, "../../../"))
MODEL_PATH = os.path.normpath(os.path.join(PROJECT_ROOT, "ml/exports/v1.0/best.onnx"))
LABELS_PATH = os.path.normpath(os.path.join(PROJECT_ROOT, "ml/exports/v1.0/labels.txt"))

# ====== THAM SỐ CHẤT LƯỢNG/HIỂN THỊ ======
DISPLAY_MIN = 0.10      # ẩn dự đoán <10%
BLUR_TOO_LOW = 50.0     # rất mờ → enhance
BLUR_A_BIT_LOW = 120.0  # hơi mờ
DARK_THRES = 80.0       # tối
BRIGHT_THRES = 200.0    # sáng gắt

# ====== HELPERS ======
def variance_of_laplacian_pil(im: Image.Image) -> float:
    g = ImageOps.grayscale(im)
    w, h = g.size
    if max(w, h) > 512:
        g = g.resize((min(w,512), min(h,512)), Image.BILINEAR)
    a = np.asarray(g, dtype=np.float32)
    k = np.array([[0,1,0],[1,-4,1],[0,1,0]], dtype=np.float32)
    H, W = a.shape
    if H < 3 or W < 3:
        return 0.0
    out = np.zeros((H-2, W-2), dtype=np.float32)
    for i in range(H-2):
        for j in range(W-2):
            patch = a[i:i+3, j:j+3]
            out[i,j] = float((patch*k).sum())
    return float(out.var())

def estimate_brightness(im: Image.Image) -> float:
    g = ImageOps.grayscale(im)
    w, h = g.size
    if max(w, h) > 512:
        g = g.resize((min(w,512), min(h,512)), Image.BILINEAR)
    arr = np.asarray(g, dtype=np.float32)
    return float(arr.mean())

def enhance_image_soft(im: Image.Image) -> Image.Image:
    im = im.convert("RGB")
    im = im.filter(ImageFilter.UnsharpMask(radius=1.2, percent=130, threshold=2))
    try:
        ycbcr = im.convert("YCbCr")
        y, cb, cr = ycbcr.split()
        y_eq = ImageOps.equalize(y)
        y_mix = Image.blend(y, y_eq, alpha=0.3)
        out = Image.merge("YCbCr", (y_mix, cb, cr)).convert("RGB")
        return out
    except Exception:
        return im

class InferenceService:
    def __init__(self, providers: Optional[list[str]] = None):
        try:
            self.detector = OnnxDetector(
                model_path=MODEL_PATH,
                labels_path=LABELS_PATH,
                input_size=(640, 640),
                conf_thres=0.25,
                iou_thres=0.45,
                providers=providers or ["CPUExecutionProvider"],  # đổi thành CUDA nếu có
            )
            logger.info("✅ ONNX model loaded successfully.")
        except Exception as e:
            logger.error(f"❌ Failed to load ONNX model: {e}")
            self.detector = None

    async def analyze(self, image_file: UploadFile):
        if not self.detector:
            raise HTTPException(status_code=500, detail="Model chưa được load.")

        try:
            raw_bytes = await image_file.read()
            if not raw_bytes:
                raise HTTPException(status_code=400, detail="Ảnh rỗng.")

            image = Image.open(io.BytesIO(raw_bytes)).convert("RGB")

            # 1) đánh giá chất lượng
            blur = variance_of_laplacian_pil(image)
            bright = estimate_brightness(image)
            too_dark = bright < DARK_THRES
            too_bright = bright > BRIGHT_THRES
            quality = {
                "blur_score": round(blur, 2),
                "brightness": round(bright, 1),
                "too_dark": too_dark,
                "too_bright": too_bright,
            }

            # 2) infer #1
            pred1 = self.detector.predict(image)  # {'label','confidence','best_cls','debug'}
            logger.info(f"📸 Pred#1: {pred1}")
            disease = pred1.get("label") or "Không xác định"
            confidence = float(pred1.get("confidence") or 0.0)
            debug = {**(pred1.get("debug") or {}), "display_threshold": DISPLAY_MIN, "model_nc": len(self.detector.labels)}
            enhanced_used = False

            # 3) enhance nếu quá mờ
            if blur < BLUR_TOO_LOW:
                enhanced = enhance_image_soft(image)
                pred2 = self.detector.predict(enhanced)
                logger.info(f"📸 Pred#2 (enhanced): {pred2}")
                enhanced_used = True
                if float(pred2.get("confidence") or 0.0) > confidence:
                    disease = pred2.get("label", disease)
                    confidence = float(pred2.get("confidence", confidence))
            debug["enhanced_used"] = enhanced_used

            # 4) áp ngưỡng hiển thị (UI)
            shown_disease = disease if confidence >= DISPLAY_MIN else "Không xác định"
            shown_conf    = confidence if confidence >= DISPLAY_MIN else 0.0

            # 5) gọi LLM
            try:
                llm_text = explain_disease_with_llm(
                    disease_name=shown_disease,
                    confidence=shown_conf,
                    db_description=None,
                    db_guideline=None
                )
            except Exception as e:
                logger.error(f"❌ LLM error: {e}")
                if shown_conf > 0 and shown_disease != "Không xác định":
                    llm_text = f"Bệnh dự đoán: {shown_disease}. Độ tin cậy: {shown_conf*100:.2f}%."
                else:
                    tips = []
                    if blur < BLUR_A_BIT_LOW: tips.append("Chụp gần hơn và giữ máy ổn định để ảnh rõ nét.")
                    if too_dark: tips.append("Tăng ánh sáng (đèn/ánh sáng tự nhiên), tránh ngược sáng.")
                    if too_bright: tips.append("Giảm chói, tránh ánh sáng gắt chiếu trực tiếp.")
                    llm_text = "Không thể sinh giải thích từ LLM." + (f" {' '.join(tips)}" if tips else "")

            # 6) trả kết quả
            return {
                "success": True,
                "result": {
                    "disease": shown_disease,
                    "confidence": round(shown_conf, 4),
                    "llm_explanation": llm_text,   # ✅ giữ khóa thống nhất
                    "quality": quality,
                    "debug": debug
                }
            }

        except HTTPException:
            raise
        except Exception as e:
            logger.error(f"❌ Inference error: {e}")
            raise HTTPException(status_code=500, detail=str(e))
