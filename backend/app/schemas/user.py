from datetime import date
from typing import Literal

from pydantic import BaseModel, EmailStr


class UserMeResponse(BaseModel):
    id: int
    email: EmailStr
    native_language: str
    target_language: str
    xp: int
    streak: int
    daily_xp_goal: int
    last_active_date: date | None

    model_config = {"from_attributes": True}


class UserUpdateRequest(BaseModel):
    native_language: Literal["Amharic", "English"] | None = None
    target_language: str | None = None
    daily_xp_goal: int | None = None


class UnitProgressResponse(BaseModel):
    unit_id: int
    unit_title: str
    completion_percentage: float


class BadgeResponse(BaseModel):
    id: int
    name: str
    description: str
    unlocked: bool
    unlock_date: str | None
    unlock_criteria: str
    icon_svg: str


class UserProfileResponse(BaseModel):
    id: int
    username: str
    email: EmailStr
    native_language: str
    target_language: str
    level: int
    current_xp: int
    level_target_xp: int
    streak: int
    daily_goal: int
    today_xp: int
    total_xp: int
    next_milestone_xp: int
    units_progress: list[UnitProgressResponse]
    badges: list[BadgeResponse]
