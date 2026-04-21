from datetime import datetime

from pydantic import BaseModel, Field


class BlockUserRequest(BaseModel):
    user_id: int = Field(gt=0)
    reason: str = Field(default="", max_length=256)


class BlockedUserResponse(BaseModel):
    user_id: int
    reason: str
    created_at: datetime


class BlockedUserListResponse(BaseModel):
    items: list[BlockedUserResponse]
