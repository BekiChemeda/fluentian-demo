from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.lesson import (
    CompleteLessonRequest,
    CompleteLessonResponse,
    LessonExplainRequest,
    LessonExplainResponse,
    LessonListResponse,
    LessonResponse,
)
from app.services.lesson_service import complete_lesson, explain_lesson, get_lesson_by_id, list_lessons

router = APIRouter(prefix="/lessons", tags=["lessons"])


@router.get("", response_model=LessonListResponse)
async def get_lessons(
    page: int = Query(default=1, ge=1),
    # Allow larger page sizes so clients can request the full lesson list
    # when needed (e.g. roadmap rendering). Keep a sensible upper bound.
    page_size: int = Query(default=50, ge=1, le=1000),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LessonListResponse:
    return await list_lessons(db, user, page, page_size)


@router.get("/{lesson_id}", response_model=LessonResponse)
async def get_lesson(
    lesson_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LessonResponse:
    return await get_lesson_by_id(db, lesson_id, user)


@router.post("/{lesson_id}/complete", response_model=CompleteLessonResponse)
async def complete(
    lesson_id: int,
    payload: CompleteLessonRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CompleteLessonResponse:
    return await complete_lesson(db, user, lesson_id, payload.score)


@router.post("/{lesson_id}/explain", response_model=LessonExplainResponse)
async def explain(
    lesson_id: int,
    payload: LessonExplainRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> LessonExplainResponse:
    return await explain_lesson(db, user, lesson_id, payload)
