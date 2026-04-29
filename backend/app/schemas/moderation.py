from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class ModerationFlagUpdateRequest(BaseModel):
    status: str = Field(min_length=2, max_length=30)
    resolution_note: str | None = Field(default=None, max_length=500)


class ModerationFlagResponse(BaseModel):
    id: UUID
    user_id: int | None = None
    source_type: str
    source_id: str
    reason_code: str
    severity: int
    status: str
    resolution_note: str | None = None
    created_at: datetime
    resolved_at: datetime | None = None

    model_config = {"from_attributes": True}


class ModerationFlagListResponse(BaseModel):
    items: list[ModerationFlagResponse]
    page: int
    page_size: int
    total: int
