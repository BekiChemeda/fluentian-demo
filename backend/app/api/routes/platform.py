from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, require_roles
from app.db.session import get_db
from app.models.user import User
from app.schemas.lesson import CompleteLessonRequest, CompleteLessonResponse, LessonResponse
from app.schemas.platform import (
    CourseCreateRequest,
    CourseListResponse,
    CourseResponse,
    CourseUpdateRequest,
    LanguageListResponse,
    LearningPathResponse,
    LessonAdminCreateRequest,
    LessonAdminUpdateRequest,
    LessonStartResponse,
    QuestionAttemptRequest,
    QuestionAttemptResponse,
    QuestionCreateRequest,
    QuestionResponse,
    QuestionUpdateRequest,
    ReviewQueueResponse,
)
from app.services.lesson_service import complete_lesson
from app.services.platform_service import (
    complete_user_lesson,
    create_admin_lesson,
    create_course,
    create_question,
    get_course,
    get_learning_path_me,
    list_courses,
    list_languages,
    list_review_queue,
    start_lesson,
    submit_question_attempt,
    update_admin_lesson,
    update_course,
    update_question,
)

router = APIRouter(tags=["learning"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]
AdminUserDep = Annotated[User, Depends(require_roles("admin"))]


@router.get("/languages", response_model=LanguageListResponse)
async def languages(db: DbDep, _: CurrentUserDep) -> LanguageListResponse:
    return LanguageListResponse(items=await list_languages(db))


@router.get("/courses", response_model=CourseListResponse)
async def courses(
    db: DbDep,
    user: CurrentUserDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> CourseListResponse:
    items, total = await list_courses(db, user, page, page_size)
    return CourseListResponse(items=items, page=page, page_size=page_size, total=total)


@router.get("/courses/{course_id}", response_model=CourseResponse)
async def course(course_id: UUID, db: DbDep, user: CurrentUserDep) -> CourseResponse:
    return await get_course(db, user, course_id)


@router.get("/learning-paths/me", response_model=LearningPathResponse)
async def learning_path_me(db: DbDep, user: CurrentUserDep) -> LearningPathResponse:
    return LearningPathResponse.model_validate(await get_learning_path_me(db, user))


@router.post("/lessons/{lesson_id}/start", response_model=LessonStartResponse)
async def start(lesson_id: int, db: DbDep, user: CurrentUserDep) -> LessonStartResponse:
    progress = await start_lesson(db, user, lesson_id)
    return LessonStartResponse(lesson_id=lesson_id, status=progress.status, started_at=progress.started_at)


@router.post("/questions/{question_id}/attempt", response_model=QuestionAttemptResponse)
async def attempt(question_id: UUID, payload: QuestionAttemptRequest, db: DbDep, user: CurrentUserDep) -> QuestionAttemptResponse:
    return QuestionAttemptResponse.model_validate(await submit_question_attempt(db, user, question_id, payload))


@router.post("/lessons/{lesson_id}/complete-schema")
async def complete_schema_lesson(
    lesson_id: int,
    payload: CompleteLessonRequest,
    db: DbDep,
    user: CurrentUserDep,
) -> dict:
    row = await complete_user_lesson(db, user, lesson_id, payload.score)
    return {"lesson_id": lesson_id, "status": row.status, "best_score": float(row.best_score)}


@router.get("/review-queue/me", response_model=ReviewQueueResponse)
async def review_queue_me(
    db: DbDep,
    user: CurrentUserDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> ReviewQueueResponse:
    items, total = await list_review_queue(db, user, page, page_size)
    return ReviewQueueResponse(
        items=[
            {
                "id": str(item.id),
                "source_lesson_id": item.source_lesson_id,
                "due_at": item.due_at.isoformat(),
                "priority": item.priority,
                "state": item.state,
            }
            for item in items
        ],
        page=page,
        page_size=page_size,
        total=total,
    )


@router.post("/admin/courses", response_model=CourseResponse)
async def admin_create_course(payload: CourseCreateRequest, db: DbDep, admin: AdminUserDep) -> CourseResponse:
    return await create_course(db, admin, payload)


@router.patch("/admin/courses/{course_id}", response_model=CourseResponse)
async def admin_update_course(
    course_id: UUID,
    payload: CourseUpdateRequest,
    db: DbDep,
    admin: AdminUserDep,
) -> CourseResponse:
    return await update_course(db, admin, course_id, payload)


@router.post("/admin/lessons", response_model=LessonResponse)
async def admin_create_lesson(payload: LessonAdminCreateRequest, db: DbDep, admin: AdminUserDep) -> LessonResponse:
    lesson = await create_admin_lesson(db, admin, payload)
    return LessonResponse.model_validate(lesson)


@router.patch("/admin/lessons/{lesson_id}", response_model=LessonResponse)
async def admin_update_lesson(
    lesson_id: int,
    payload: LessonAdminUpdateRequest,
    db: DbDep,
    admin: AdminUserDep,
) -> LessonResponse:
    lesson = await update_admin_lesson(db, admin, lesson_id, payload)
    return LessonResponse.model_validate(lesson)


@router.post("/admin/questions", response_model=QuestionResponse)
async def admin_create_question(payload: QuestionCreateRequest, db: DbDep, admin: AdminUserDep) -> QuestionResponse:
    return QuestionResponse.model_validate(await create_question(db, admin, payload))


@router.patch("/admin/questions/{question_id}", response_model=QuestionResponse)
async def admin_update_question(
    question_id: UUID,
    payload: QuestionUpdateRequest,
    db: DbDep,
    admin: AdminUserDep,
) -> QuestionResponse:
    return QuestionResponse.model_validate(await update_question(db, admin, question_id, payload))
