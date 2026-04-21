from datetime import datetime

from pydantic import BaseModel, Field


class DelfQuestion(BaseModel):
    id: str
    prompt: str
    choices: list[str] = Field(default_factory=list)
    answer: str


class DelfTestSummaryResponse(BaseModel):
    id: int
    title: str
    level: str
    description: str
    question_count: int
    passing_score: int


class DelfTestDetailResponse(BaseModel):
    id: int
    title: str
    level: str
    description: str
    questions: list[DelfQuestion]
    passing_score: int


class DelfAnswerItem(BaseModel):
    question_id: str
    answer: str


class DelfSubmitRequest(BaseModel):
    answers: list[DelfAnswerItem] = Field(default_factory=list)


class DelfSubmitResponse(BaseModel):
    result_id: int
    score: int
    correct_count: int
    total_questions: int
    passed: bool


class DelfResultItemResponse(BaseModel):
    result_id: int
    test_id: int
    test_title: str
    level: str
    score: int
    correct_count: int
    total_questions: int
    submitted_at: datetime


class DelfResultsResponse(BaseModel):
    items: list[DelfResultItemResponse]
