from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field


class LanguageResponse(BaseModel):
    id: UUID
    iso_code: str
    english_name: str
    native_name: str | None = None
    is_active: bool

    model_config = {"from_attributes": True}


class LanguageListResponse(BaseModel):
    items: list[LanguageResponse]


class CourseCreateRequest(BaseModel):
    target_language_id: UUID
    code: str = Field(min_length=2, max_length=50)
    level_min: str = Field(default="a1", max_length=8)
    level_max: str = Field(default="a1", max_length=8)
    title: str = Field(min_length=2, max_length=180)
    description: str = ""
    language_id: UUID | None = None
    is_published: bool = False


class CourseUpdateRequest(BaseModel):
    code: str | None = Field(default=None, min_length=2, max_length=50)
    level_min: str | None = Field(default=None, max_length=8)
    level_max: str | None = Field(default=None, max_length=8)
    title: str | None = Field(default=None, min_length=2, max_length=180)
    description: str | None = None
    language_id: UUID | None = None
    is_published: bool | None = None
    archived: bool | None = None


class CourseResponse(BaseModel):
    id: UUID
    target_language_id: UUID
    code: str
    level_min: str
    level_max: str
    title: str | None = None
    description: str | None = None
    is_published: bool
    published_at: datetime | None = None
    archived_at: datetime | None = None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class CourseListResponse(BaseModel):
    items: list[CourseResponse]
    page: int
    page_size: int
    total: int


class LessonAdminCreateRequest(BaseModel):
    course_id: UUID | None = None
    level: str = "A1"
    type: str = "vocabulary"
    lesson_kind: str | None = None
    content: dict[str, Any] = Field(default_factory=dict)
    xp_reward: int = Field(default=10, ge=0, le=1000)
    order_index: int = Field(ge=1)
    is_published: bool = False


class LessonAdminUpdateRequest(BaseModel):
    course_id: UUID | None = None
    level: str | None = None
    type: str | None = None
    lesson_kind: str | None = None
    content: dict[str, Any] | None = None
    xp_reward: int | None = Field(default=None, ge=0, le=1000)
    order_index: int | None = Field(default=None, ge=1)
    is_published: bool | None = None
    archived: bool | None = None


class QuestionCreateRequest(BaseModel):
    lesson_id: int
    question_kind: str = Field(min_length=2, max_length=40)
    sequence_no: int = Field(ge=1)
    difficulty: float = Field(default=0.5, ge=0, le=1)
    prompt_payload: dict[str, Any]
    grading_payload: dict[str, Any]
    hint_payload: dict[str, Any] | None = None


class QuestionUpdateRequest(BaseModel):
    question_kind: str | None = Field(default=None, min_length=2, max_length=40)
    sequence_no: int | None = Field(default=None, ge=1)
    difficulty: float | None = Field(default=None, ge=0, le=1)
    prompt_payload: dict[str, Any] | None = None
    grading_payload: dict[str, Any] | None = None
    hint_payload: dict[str, Any] | None = None


class QuestionResponse(BaseModel):
    id: UUID
    lesson_id: int
    question_kind: str
    sequence_no: int
    difficulty: float
    prompt_payload: dict[str, Any]
    hint_payload: dict[str, Any] | None = None
    created_at: datetime

    model_config = {"from_attributes": True}


class QuestionAttemptRequest(BaseModel):
    answer_payload: dict[str, Any]
    latency_ms: int | None = Field(default=None, ge=0)
    test_mode: bool = False


class QuestionAttemptResponse(BaseModel):
    id: UUID
    question_id: UUID
    attempt_no: int
    score: float
    is_correct: bool
    submitted_at: datetime

    model_config = {"from_attributes": True}


class LearningPathResponse(BaseModel):
    course_id: UUID
    course_code: str
    path_id: UUID | None = None
    current_level: str
    units: list[dict[str, Any]] = Field(default_factory=list)


class LessonStartResponse(BaseModel):
    lesson_id: int
    status: str
    started_at: datetime


class ReviewQueueResponse(BaseModel):
    items: list[dict[str, Any]]
    page: int
    page_size: int
    total: int
