from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class DeviceTokenUpsertRequest(BaseModel):
    token: str = Field(min_length=8, max_length=512)
    platform: Literal["android", "ios", "web", "unknown"] = "unknown"


class NotificationItemResponse(BaseModel):
    id: int
    type: str
    title: str
    body: str
    metadata: dict[str, Any]
    is_read: bool
    created_at: datetime


class NotificationListResponse(BaseModel):
    items: list[NotificationItemResponse]


class NotificationReadRequest(BaseModel):
    notification_ids: list[int] = Field(default_factory=list)
    mark_all: bool = False


class NotificationReadResponse(BaseModel):
    updated: int
