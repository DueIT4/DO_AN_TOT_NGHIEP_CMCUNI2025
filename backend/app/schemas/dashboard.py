# app/schemas/dashboard.py
from datetime import datetime, date
from typing import List, Optional
from pydantic import BaseModel


class DetectionTimePoint(BaseModel):
    date: date
    count: int


class DiseaseStat(BaseModel):
    disease_name: str
    count: int


class TicketStatusStat(BaseModel):
    status: str
    count: int


class RecentDetectionItem(BaseModel):
    detection_id: int
    user_id: Optional[int] = None
    username: Optional[str] = None
    disease_name: Optional[str] = None
    confidence: Optional[float] = None
    created_at: datetime


class RecentTicketItem(BaseModel):
    ticket_id: int
    user_id: Optional[int] = None
    username: Optional[str] = None
    status: Optional[str] = None
    title: Optional[str] = None
    created_at: datetime


class DashboardSummary(BaseModel):
    # Devices
    total_devices: int
    active_devices: int
    inactive_devices: int

    # Users
    total_users: int
    new_users: int

    # Detections
    total_detections: int
    detections_over_time: List[DetectionTimePoint]
    top_diseases: List[DiseaseStat]

    # Tickets
    total_tickets: int
    open_tickets: int
    tickets_by_status: List[TicketStatusStat]

    # Latest lists
    recent_detections: List[RecentDetectionItem]
    recent_tickets: List[RecentTicketItem]
