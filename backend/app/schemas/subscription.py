from datetime import date, datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class SubscriptionResponse(BaseModel):
    id: UUID | None = None
    tier: str
    status: str
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    features: dict[str, int | None] = Field(default_factory=dict)


class UsageResponse(BaseModel):
    usage_date: date
    items: list[dict[str, Any]]


class UsageEventRequest(BaseModel):
    feature_key: str = Field(min_length=2, max_length=80)
    quantity: int = Field(default=1, ge=1, le=1000)
    metadata: dict[str, Any] | None = None


class UsageEventResponse(BaseModel):
    feature_key: str
    used_count: int
    limit_count: int | None = None
    allowed: bool


class AIRequest(BaseModel):
    text: str = Field(min_length=1, max_length=4000)
    lesson_id: int | None = None
    question_id: UUID | None = None
    source_type: str = "ai"


class AIResponse(BaseModel):
    id: UUID
    result: str
    created_at: datetime
