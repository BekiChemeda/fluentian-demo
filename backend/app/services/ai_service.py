from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.learning_schema import AIExplanation
from app.models.user import User
from app.schemas.subscription import AIRequest
from app.services.community_service import generate_with_gemini
from app.services.usage_service import record_usage_event


async def create_ai_response(db: AsyncSession, user: User, payload: AIRequest, feature_key: str) -> AIExplanation:
    await record_usage_event(db, user, feature_key, quantity=1, metadata={"source_type": payload.source_type})
    prompt = (
        "You are Fluentian, a concise French learning tutor. "
        f"Explain in {user.native_language or 'English'} for a {user.cefr_level} learner. "
        f"Task: {feature_key}. Input: {payload.text}"
    )
    try:
        result = await generate_with_gemini(prompt, temperature=0.2, max_output_tokens=420)
    except Exception:
        result = _fallback_response(payload.text, feature_key)

    row = AIExplanation(
        user_id=user.id,
        lesson_id=payload.lesson_id,
        question_id=payload.question_id,
        source_type=payload.source_type,
        source_id=str(payload.question_id or payload.lesson_id or ""),
        base_language=user.native_language,
        target_language=user.target_language,
        user_input=payload.text,
        explanation_text=result,
        cefr_level=user.cefr_level,
        model_name=get_settings().gemini_model,
        created_at=datetime.now(UTC),
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def list_my_explanations(db: AsyncSession, user: User) -> list[AIExplanation]:
    result = await db.execute(
        select(AIExplanation).where(AIExplanation.user_id == user.id).order_by(AIExplanation.created_at.desc()).limit(50)
    )
    return list(result.scalars().all())


def _fallback_response(text: str, feature_key: str) -> str:
    if feature_key == "ai_correct":
        return f"Review this sentence carefully: {text}"
    if feature_key == "pronunciation_feedback":
        return "Practice slowly, keep French vowel sounds short and clear, then repeat at natural speed."
    return f"Here is a simple explanation: {text}"
