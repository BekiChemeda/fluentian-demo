from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.learning_schema import (
    AIExplanation,
    Course,
    CourseI18n,
    Language,
    LearningPath,
    PathUnit,
    PathUnitI18n,
    Question,
    ReviewQueueItem,
    UnitLesson,
    UserLessonProgress,
    UserQuestionAttempt,
)
from app.models.lesson import Lesson
from app.models.progress import Progress
from app.models.user import User
from app.schemas.platform import (
    CourseCreateRequest,
    CourseResponse,
    CourseUpdateRequest,
    LessonAdminCreateRequest,
    LessonAdminUpdateRequest,
    QuestionAttemptRequest,
    QuestionCreateRequest,
    QuestionUpdateRequest,
)


async def list_languages(db: AsyncSession) -> list[Language]:
    result = await db.execute(select(Language).where(Language.is_active.is_(True)).order_by(Language.english_name))
    return list(result.scalars().all())


async def list_courses(db: AsyncSession, user: User, page: int, page_size: int) -> tuple[list[CourseResponse], int]:
    stmt = select(Course).where(Course.archived_at.is_(None))
    if user.role not in {"admin", "moderator"}:
        stmt = stmt.where(Course.is_published.is_(True))
    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    result = await db.execute(stmt.order_by(Course.code).offset((page - 1) * page_size).limit(page_size))
    courses = list(result.scalars().all())
    return [await _course_response(db, course) for course in courses], int(total or 0)


async def get_course(db: AsyncSession, user: User, course_id: UUID) -> CourseResponse:
    course = await db.get(Course, course_id)
    if course is None or course.archived_at is not None:
        raise AppException("Course not found", status_code=404, code="course_not_found")
    if not course.is_published and user.role not in {"admin", "moderator"}:
        raise AppException("Course not found", status_code=404, code="course_not_found")
    return await _course_response(db, course)


async def create_course(db: AsyncSession, actor: User, payload: CourseCreateRequest) -> CourseResponse:
    now = datetime.now(UTC)
    course = Course(
        target_language_id=payload.target_language_id,
        code=payload.code,
        level_min=payload.level_min.lower(),
        level_max=payload.level_max.lower(),
        is_published=payload.is_published,
        created_by=actor.id,
        updated_by=actor.id,
        published_at=now if payload.is_published else None,
        created_at=now,
        updated_at=now,
    )
    db.add(course)
    await db.flush()
    db.add(
        CourseI18n(
            course_id=course.id,
            language_id=payload.language_id or payload.target_language_id,
            title=payload.title,
            description=payload.description,
        )
    )
    await db.commit()
    await db.refresh(course)
    return await _course_response(db, course)


async def update_course(db: AsyncSession, actor: User, course_id: UUID, payload: CourseUpdateRequest) -> CourseResponse:
    course = await db.get(Course, course_id)
    if course is None or course.archived_at is not None:
        raise AppException("Course not found", status_code=404, code="course_not_found")
    now = datetime.now(UTC)
    data = payload.model_dump(exclude_unset=True)
    for field in ("code", "level_min", "level_max", "is_published"):
        if field in data:
            setattr(course, field, data[field])
    if payload.is_published and course.published_at is None:
        course.published_at = now
    if payload.archived is True:
        course.archived_at = now
    course.updated_by = actor.id
    course.updated_at = now

    if payload.title is not None or payload.description is not None:
        language_id = payload.language_id or course.target_language_id
        i18n_result = await db.execute(
            select(CourseI18n).where(CourseI18n.course_id == course.id, CourseI18n.language_id == language_id)
        )
        i18n = i18n_result.scalar_one_or_none()
        if i18n is None:
            i18n = CourseI18n(course_id=course.id, language_id=language_id, title=payload.title or course.code)
            db.add(i18n)
        if payload.title is not None:
            i18n.title = payload.title
        if payload.description is not None:
            i18n.description = payload.description

    await db.commit()
    await db.refresh(course)
    return await _course_response(db, course)


async def get_learning_path_me(db: AsyncSession, user: User) -> dict:
    course_result = await db.execute(
        select(Course)
        .where(Course.is_published.is_(True), Course.archived_at.is_(None))
        .order_by(Course.level_min, Course.code)
        .limit(1)
    )
    course = course_result.scalar_one_or_none()
    if course is None:
        return {"course_id": None, "course_code": "", "path_id": None, "current_level": user.cefr_level, "units": []}

    path_result = await db.execute(
        select(LearningPath).where(LearningPath.course_id == course.id, LearningPath.is_active.is_(True)).limit(1)
    )
    path = path_result.scalar_one_or_none()
    units: list[dict] = []
    if path is not None:
        unit_result = await db.execute(select(PathUnit).where(PathUnit.learning_path_id == path.id).order_by(PathUnit.unit_no))
        for unit in unit_result.scalars().all():
            title_result = await db.execute(select(PathUnitI18n).where(PathUnitI18n.unit_id == unit.id).limit(1))
            title = title_result.scalar_one_or_none()
            lessons_result = await db.execute(
                select(UnitLesson.lesson_id).where(UnitLesson.unit_id == unit.id).order_by(UnitLesson.sort_no)
            )
            units.append(
                {
                    "id": str(unit.id),
                    "unit_no": unit.unit_no,
                    "unit_kind": unit.unit_kind,
                    "cefr_level": unit.cefr_level,
                    "title": title.title if title else f"Unit {unit.unit_no}",
                    "lesson_ids": list(lessons_result.scalars().all()),
                }
            )
    return {
        "course_id": course.id,
        "course_code": course.code,
        "path_id": path.id if path else None,
        "current_level": user.cefr_level,
        "units": units,
    }


async def start_lesson(db: AsyncSession, user: User, lesson_id: int) -> UserLessonProgress:
    lesson = await _get_visible_lesson(db, user, lesson_id)
    now = datetime.now(UTC)
    result = await db.execute(
        select(UserLessonProgress).where(UserLessonProgress.user_id == user.id, UserLessonProgress.lesson_id == lesson.id)
    )
    progress = result.scalar_one_or_none()
    if progress is None:
        progress = UserLessonProgress(
            user_id=user.id,
            lesson_id=lesson.id,
            status="in_progress",
            started_at=now,
            last_activity_at=now,
        )
        db.add(progress)
    else:
        progress.status = "in_progress" if progress.status != "completed" else progress.status
        progress.last_activity_at = now
    await db.commit()
    await db.refresh(progress)
    return progress


async def complete_user_lesson(db: AsyncSession, user: User, lesson_id: int, score: int) -> UserLessonProgress:
    await _get_visible_lesson(db, user, lesson_id)
    now = datetime.now(UTC)
    result = await db.execute(
        select(UserLessonProgress).where(UserLessonProgress.user_id == user.id, UserLessonProgress.lesson_id == lesson_id)
    )
    progress = result.scalar_one_or_none()
    if progress is None:
        progress = UserLessonProgress(user_id=user.id, lesson_id=lesson_id, started_at=now, last_activity_at=now)
        db.add(progress)
    progress.status = "completed"
    progress.mastery_score = score
    progress.best_score = max(float(progress.best_score or 0), score)
    progress.completed_at = progress.completed_at or now
    progress.last_activity_at = now
    await db.commit()
    await db.refresh(progress)
    return progress


async def create_question(db: AsyncSession, actor: User, payload: QuestionCreateRequest) -> Question:
    lesson = await db.get(Lesson, payload.lesson_id)
    if lesson is None:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")
    now = datetime.now(UTC)
    question = Question(
        lesson_id=payload.lesson_id,
        question_kind=payload.question_kind,
        sequence_no=payload.sequence_no,
        difficulty=payload.difficulty,
        prompt_payload=payload.prompt_payload,
        grading_payload=payload.grading_payload,
        hint_payload=payload.hint_payload,
        created_by=actor.id,
        updated_by=actor.id,
        created_at=now,
        updated_at=now,
    )
    db.add(question)
    await db.commit()
    await db.refresh(question)
    return question


async def update_question(db: AsyncSession, actor: User, question_id: UUID, payload: QuestionUpdateRequest) -> Question:
    question = await db.get(Question, question_id)
    if question is None:
        raise AppException("Question not found", status_code=404, code="question_not_found")
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(question, key, value)
    question.updated_by = actor.id
    question.updated_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(question)
    return question


async def submit_question_attempt(
    db: AsyncSession,
    user: User,
    question_id: UUID,
    payload: QuestionAttemptRequest,
) -> UserQuestionAttempt:
    question = await db.get(Question, question_id)
    if question is None:
        raise AppException("Question not found", status_code=404, code="question_not_found")
    lesson = await db.get(Lesson, question.lesson_id)
    if lesson is None:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")
    if not lesson.is_published and user.role != "admin" and not payload.test_mode:
        raise AppException("Lesson is not published", status_code=403, code="lesson_unpublished")

    attempt_count = await db.scalar(
        select(func.count(UserQuestionAttempt.id)).where(
            UserQuestionAttempt.user_id == user.id,
            UserQuestionAttempt.question_id == question.id,
        )
    )
    expected = question.grading_payload.get("answer")
    submitted = payload.answer_payload.get("answer")
    is_correct = expected is not None and str(submitted).strip().casefold() == str(expected).strip().casefold()
    score = 1.0 if is_correct else 0.0
    attempt = UserQuestionAttempt(
        user_id=user.id,
        lesson_id=question.lesson_id,
        question_id=question.id,
        attempt_no=int(attempt_count or 0) + 1,
        answer_payload=payload.answer_payload,
        score=score,
        is_correct=is_correct,
        latency_ms=payload.latency_ms,
        submitted_at=datetime.now(UTC),
    )
    db.add(attempt)
    await db.commit()
    await db.refresh(attempt)
    return attempt


async def create_admin_lesson(db: AsyncSession, actor: User, payload: LessonAdminCreateRequest) -> Lesson:
    now = datetime.now(UTC)
    lesson = Lesson(
        course_id=payload.course_id,
        level=payload.level,
        type=payload.type,
        lesson_kind=payload.lesson_kind or payload.type,
        content=payload.content,
        xp_reward=payload.xp_reward,
        order_index=payload.order_index,
        is_published=payload.is_published,
        created_by=actor.id,
        updated_by=actor.id,
        published_at=now if payload.is_published else None,
        created_at=now,
        updated_at=now,
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)
    return lesson


async def update_admin_lesson(db: AsyncSession, actor: User, lesson_id: int, payload: LessonAdminUpdateRequest) -> Lesson:
    lesson = await db.get(Lesson, lesson_id)
    if lesson is None:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")
    now = datetime.now(UTC)
    for key, value in payload.model_dump(exclude_unset=True, exclude={"archived"}).items():
        setattr(lesson, key, value)
    if payload.is_published and lesson.published_at is None:
        lesson.published_at = now
    if payload.archived is True:
        lesson.archived_at = now
    lesson.updated_by = actor.id
    lesson.updated_at = now
    await db.commit()
    await db.refresh(lesson)
    return lesson


async def list_review_queue(db: AsyncSession, user: User, page: int, page_size: int) -> tuple[list[ReviewQueueItem], int]:
    stmt = select(ReviewQueueItem).where(ReviewQueueItem.user_id == user.id, ReviewQueueItem.state == "due")
    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    result = await db.execute(stmt.order_by(ReviewQueueItem.due_at, ReviewQueueItem.priority.desc()).offset((page - 1) * page_size).limit(page_size))
    return list(result.scalars().all()), int(total or 0)


async def _get_visible_lesson(db: AsyncSession, user: User, lesson_id: int) -> Lesson:
    lesson = await db.get(Lesson, lesson_id)
    if lesson is None or lesson.archived_at is not None:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")
    if not lesson.is_published and user.role not in {"admin", "moderator"}:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")
    return lesson


async def _course_response(db: AsyncSession, course: Course) -> CourseResponse:
    i18n_result = await db.execute(select(CourseI18n).where(CourseI18n.course_id == course.id).limit(1))
    i18n = i18n_result.scalar_one_or_none()
    return CourseResponse(
        id=course.id,
        target_language_id=course.target_language_id,
        code=course.code,
        level_min=course.level_min,
        level_max=course.level_max,
        title=i18n.title if i18n else None,
        description=i18n.description if i18n else None,
        is_published=course.is_published,
        published_at=course.published_at,
        archived_at=course.archived_at,
        created_at=course.created_at,
        updated_at=course.updated_at,
    )
