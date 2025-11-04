from fastapi import APIRouter, UploadFile, File, HTTPException
from app.services.inference_service import InferenceService

router = APIRouter(prefix="/detect", tags=["Detection"])

service = InferenceService()

# routes
@router.post("/upload")
async def detect_image(image: UploadFile = File(...)):
    try:
        result = await service.analyze(image)
        # đảm bảo cấu trúc trả về
        return {"success": True, "result": result}
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
