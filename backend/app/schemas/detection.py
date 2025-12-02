from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict


class DetectionHistoryItem(BaseModel):
  detection_id: int
  disease_name: str
  confidence: float
  img_url: Optional[str]
  source_type: str  # "camera" hoặc "upload"
  created_at: datetime

  model_config = ConfigDict(from_attributes=True)


class DetectionDetail(BaseModel):
  detection_id: int
  disease_name: str
  confidence: float
  img_url: Optional[str]
  created_at: datetime
  description: Optional[str]
  treatment_guideline: Optional[str]

  model_config = ConfigDict(from_attributes=True)


