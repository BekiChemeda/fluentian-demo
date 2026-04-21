import json
from datetime import date

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.lesson import Lesson
from app.models.progress import Progress
from app.models.user import User
from app.services.community_service import generate_with_gemini
from app.schemas.lesson import (
    CompleteLessonResponse,
    LessonExplainRequest,
    LessonExplainResponse,
    LessonListResponse,
    LessonResponse,
)


def _normalize_content(raw: dict, lesson_type: str) -> dict:
    if not isinstance(raw, dict):
        return {"blocks": []}

    existing_blocks = raw.get("blocks")
    if isinstance(existing_blocks, list) and existing_blocks:
        return raw

    question = str(raw.get("question", "Practice block"))
    answer = str(raw.get("answer", ""))
    choices = [str(item) for item in raw.get("choices", [])] if isinstance(raw.get("choices"), list) else []

    block_type = "translation_mcq" if choices else "sentence"
    if lesson_type == "dialogue":
        block_type = "dialogue"
    if lesson_type == "ordering":
        block_type = "ordering"

    fallback_block = {
        "type": block_type,
        "title": question,
        "hint": "Focus on meaning and sentence pattern.",
        "base_explanation": "Base-language explanation will be provided for this block.",
        "explanation_placement": "middle",
        "has_question": True,
        "answer": answer,
        "choices": choices,
        "tokens": [],
        "dialogue": [],
    }

    normalized = dict(raw)
    normalized["blocks"] = [fallback_block]
    return normalized


def _extract_json_payload(text: str) -> dict:
    raw = text.strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.startswith("json"):
            raw = raw[4:].strip()
    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        raw = raw[start : end + 1]
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    return {}


async def list_lessons(db: AsyncSession, user: User, page: int, page_size: int) -> LessonListResponse:
    total_result = await db.execute(select(func.count(Lesson.id)))
    total = total_result.scalar_one()

    result = await db.execute(
        select(Lesson).order_by(Lesson.order_index).offset((page - 1) * page_size).limit(page_size)
    )
    lessons = result.scalars().all()

    all_result = await db.execute(select(Lesson).order_by(Lesson.order_index))
    all_lessons = all_result.scalars().all()

    progress_result = await db.execute(select(Progress).where(Progress.user_id == user.id))
    progress_map = {p.lesson_id: p for p in progress_result.scalars().all()}
    unlocked_map: dict[int, bool] = {}
    previous_completed = True
    for lesson in all_lessons:
        unlocked_map[lesson.id] = previous_completed
        lesson_progress = progress_map.get(lesson.id)
        previous_completed = bool(lesson_progress and lesson_progress.completed)

    items = [
        LessonResponse(
            id=lesson.id,
            level=lesson.level,
            type=lesson.type,
            content=_normalize_content(lesson.content, lesson.type),
            xp_reward=lesson.xp_reward,
            order_index=lesson.order_index,
            completed=bool(progress_map.get(lesson.id) and progress_map[lesson.id].completed),
            unlocked=unlocked_map.get(lesson.id, False),
        )
        for lesson in lessons
    ]
    return LessonListResponse(items=items, page=page, page_size=page_size, total=total)


async def get_lesson_by_id(db: AsyncSession, lesson_id: int, user: User) -> LessonResponse:
    lesson_result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    lesson = lesson_result.scalar_one_or_none()
    if not lesson:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")

    progress_result = await db.execute(
        select(Progress).where(Progress.user_id == user.id, Progress.lesson_id == lesson_id)
    )
    progress = progress_result.scalar_one_or_none()

    previous_lesson_result = await db.execute(
        select(Lesson)
        .where(Lesson.order_index < lesson.order_index)
        .order_by(Lesson.order_index.desc())
        .limit(1)
    )
    previous_lesson = previous_lesson_result.scalar_one_or_none()
    unlocked = True
    if previous_lesson is not None:
        previous_progress_result = await db.execute(
            select(Progress).where(
                Progress.user_id == user.id,
                Progress.lesson_id == previous_lesson.id,
            )
        )
        previous_progress = previous_progress_result.scalar_one_or_none()
        unlocked = bool(previous_progress and previous_progress.completed)

    return LessonResponse(
        id=lesson.id,
        level=lesson.level,
        type=lesson.type,
        content=_normalize_content(lesson.content, lesson.type),
        xp_reward=lesson.xp_reward,
        order_index=lesson.order_index,
        completed=bool(progress and progress.completed),
        unlocked=unlocked,
    )


async def complete_lesson(db: AsyncSession, user: User, lesson_id: int, score: int) -> CompleteLessonResponse:
    lesson_result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    lesson = lesson_result.scalar_one_or_none()
    if not lesson:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")

    previous_lesson_result = await db.execute(
        select(Lesson)
        .where(Lesson.order_index < lesson.order_index)
        .order_by(Lesson.order_index.desc())
        .limit(1)
    )
    previous_lesson = previous_lesson_result.scalar_one_or_none()
    if previous_lesson is not None:
        previous_progress_result = await db.execute(
            select(Progress).where(
                Progress.user_id == user.id,
                Progress.lesson_id == previous_lesson.id,
            )
        )
        previous_progress = previous_progress_result.scalar_one_or_none()
        if not (previous_progress and previous_progress.completed):
            raise AppException("Lesson is locked", status_code=403, code="lesson_locked")

    progress_result = await db.execute(
        select(Progress).where(Progress.user_id == user.id, Progress.lesson_id == lesson_id)
    )
    progress = progress_result.scalar_one_or_none()

    first_completion = False
    if progress is None:
        progress = Progress(user_id=user.id, lesson_id=lesson_id, completed=True, score=score)
        db.add(progress)
        first_completion = True
    else:
        if not progress.completed:
            first_completion = True
        progress.completed = True
        progress.score = max(progress.score, score)

    if first_completion:
        user.xp += lesson.xp_reward
        today = date.today()
        if user.last_active_date is None:
            user.streak = 1
        else:
            days_diff = (today - user.last_active_date).days
            if days_diff == 1:
                user.streak += 1
            elif days_diff > 1:
                user.streak = 1
        user.last_active_date = today

    await db.commit()
    await db.refresh(user)
    await db.refresh(progress)

    return CompleteLessonResponse(
        lesson_id=lesson_id,
        completed=progress.completed,
        score=progress.score,
        xp_earned=lesson.xp_reward if first_completion else 0,
        total_xp=user.xp,
        streak=user.streak,
    )


async def explain_lesson(
    db: AsyncSession,
    user: User,
    lesson_id: int,
    payload: LessonExplainRequest,
) -> LessonExplainResponse:
    lesson_result = await db.execute(select(Lesson).where(Lesson.id == lesson_id))
    lesson = lesson_result.scalar_one_or_none()
    if not lesson:
        raise AppException("Lesson not found", status_code=404, code="lesson_not_found")

    base_language = user.native_language if user.native_language in {"Amharic", "English"} else "English"
    fallback = LessonExplainResponse(
        simple=f"{payload.block_title}: {payload.block_hint or 'Review this lesson block carefully.'}",
        examples=[],
        rules=[
            "Focus on the pattern shown in this block.",
        ],
    )

    action_instruction = {
        "simplify": "Explain as if the learner is a complete beginner.",
        "examples": "Give more practical examples with French + translation.",
        "quiz": "Create a short 3-question quiz based on this lesson block.",
    }.get(payload.action, "Explain this clearly and concisely for the learner.")

    prompt = (
        "You are a French lesson assistant. "
        f"Explain in {base_language}. "
        "Examples must keep French first, then translation. "
        f"Learner proficiency: {lesson.level}. "
        f"Lesson type: {lesson.type}. "
        f"Lesson content JSON: {lesson.content}. "
        f"Current block title: {payload.block_title}. "
        f"Current block hint: {payload.block_hint}. "
        f"Current block answer target: {payload.block_answer}. "
        f"Focus snippet: {payload.inline_context or 'none'}. "
        f"{action_instruction} "
        "Return strict JSON with keys: simple (string), examples (array of strings), rules (array of strings)."
    )

    try:
        text = await generate_with_gemini(
            prompt,
            temperature=0.2,
            max_output_tokens=320,
            response_mime_type="application/json",
        )
        parsed = _extract_json_payload(text)

        simple = str(parsed.get("simple") or "").strip()
        examples = parsed.get("examples") or []
        rules = parsed.get("rules") or []

        if not isinstance(examples, list):
            examples = []
        if not isinstance(rules, list):
            rules = []

        sanitized_examples = [str(item).strip() for item in examples if str(item).strip()]
        sanitized_rules = [str(item).strip() for item in rules if str(item).strip()]

        if not simple:
            simple = fallback.simple
        if not sanitized_examples:
            sanitized_examples = fallback.examples
        if not sanitized_rules:
            sanitized_rules = fallback.rules

        return LessonExplainResponse(
            simple=simple,
            examples=sanitized_examples,
            rules=sanitized_rules,
        )
    except Exception:
        return fallback
