# app/schemas/detect.py
from typing import List, Optional, Any
from pydantic import BaseModel


class BBox(BaseModel):
    x1: float
    y1: float
    x2: float
    y2: float


class DetectionItem(BaseModel):
    class_id: int
    class_name: str
    confidence: float
    bbox: BBox
    model_version: str


class DetectResponse(BaseModel):
    file_name: str
    img_id: int
    file_url: str
    num_detections: int
    detections: List[DetectionItem]
    disease_summary: Optional[str] = None
    care_instructions: Optional[str] = None

    class Config:
        orm_mode = True
