from pydantic import BaseModel
from typing import Optional

class DetectExplainResp(BaseModel):
    disease: str
    confidence: float
    explanation: str
    img_id: Optional[int] = None
    detection_id: Optional[int] = None

    class Config:
        orm_mode = True
