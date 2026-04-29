from datetime import datetime, time
from uuid import UUID

from pydantic import BaseModel, Field, model_validator


class TutorProfileResponse(BaseModel):
    id: UUID
    user_id: int
    headline: str
    bio: str
    languages: str
    hourly_rate: float
    currency: str
    timezone: str
    is_active: bool

    model_config = {"from_attributes": True}


class TutorListResponse(BaseModel):
    items: list[TutorProfileResponse]
    page: int
    page_size: int
    total: int


class AvailabilityCreateRequest(BaseModel):
    weekday: int = Field(ge=0, le=6)
    start_time: time
    end_time: time
    timezone: str = "UTC"

    @model_validator(mode="after")
    def validate_times(self) -> "AvailabilityCreateRequest":
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be after start_time")
        return self


class AvailabilityResponse(BaseModel):
    id: UUID
    tutor_user_id: int
    weekday: int
    start_time: time
    end_time: time
    timezone: str
    is_active: bool

    model_config = {"from_attributes": True}


class BookingCreateRequest(BaseModel):
    tutor_user_id: int
    starts_at: datetime
    ends_at: datetime
    topic: str = Field(default="", max_length=180)

    @model_validator(mode="after")
    def validate_times(self) -> "BookingCreateRequest":
        if self.ends_at <= self.starts_at:
            raise ValueError("ends_at must be after starts_at")
        return self


class BookingCancelRequest(BaseModel):
    reason: str = Field(default="", max_length=500)


class BookingResponse(BaseModel):
    id: UUID
    student_user_id: int
    tutor_user_id: int
    starts_at: datetime
    ends_at: datetime
    status: str
    topic: str
    meeting_url: str | None = None
    cancellation_reason: str | None = None
    cancelled_at: datetime | None = None
    completed_at: datetime | None = None

    model_config = {"from_attributes": True}


class BookingListResponse(BaseModel):
    items: list[BookingResponse]
    page: int
    page_size: int
    total: int
