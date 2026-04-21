from datetime import datetime

from pydantic import BaseModel


class RecordingResponse(BaseModel):
    session_id: int
    recording_url: str
    expires_at: datetime


class RecordingListResponse(BaseModel):
    items: list[RecordingResponse]
