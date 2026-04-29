from datetime import datetime
from uuid import UUID

from pydantic import BaseModel, Field


class OpportunityCreateRequest(BaseModel):
    category_id: UUID | None = None
    title: str = Field(min_length=2, max_length=180)
    provider_name: str = Field(min_length=2, max_length=180)
    opportunity_type: str = Field(min_length=2, max_length=60)
    country_code: str | None = Field(default=None, min_length=2, max_length=2)
    url: str | None = Field(default=None, max_length=1024)
    description: str = Field(min_length=2)
    eligibility: str | None = None
    language_requirements: str | None = None
    deadline_at: datetime | None = None
    is_published: bool = False
    metadata: dict | None = None


class OpportunityUpdateRequest(BaseModel):
    category_id: UUID | None = None
    title: str | None = Field(default=None, min_length=2, max_length=180)
    provider_name: str | None = Field(default=None, min_length=2, max_length=180)
    opportunity_type: str | None = Field(default=None, min_length=2, max_length=60)
    country_code: str | None = Field(default=None, min_length=2, max_length=2)
    url: str | None = Field(default=None, max_length=1024)
    description: str | None = Field(default=None, min_length=2)
    eligibility: str | None = None
    language_requirements: str | None = None
    deadline_at: datetime | None = None
    is_published: bool | None = None


class OpportunityResponse(BaseModel):
    id: UUID
    category_id: UUID | None = None
    title: str
    provider_name: str
    opportunity_type: str
    country_code: str | None = None
    url: str | None = None
    description: str
    eligibility: str | None = None
    language_requirements: str | None = None
    deadline_at: datetime | None = None
    is_published: bool
    published_at: datetime | None = None
    archived_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class OpportunityListResponse(BaseModel):
    items: list[OpportunityResponse]
    page: int
    page_size: int
    total: int


class GuidanceRequest(BaseModel):
    question: str = Field(min_length=1, max_length=2000)


class GuidanceResponse(BaseModel):
    id: UUID
    opportunity_id: UUID
    question: str
    ai_response: str
    created_at: datetime

    model_config = {"from_attributes": True}
