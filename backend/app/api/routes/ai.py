from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.subscription import AIRequest, AIResponse
from app.services.ai_service import create_ai_response, list_my_explanations

router = APIRouter(prefix="/ai", tags=["ai"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.post("/explain", response_model=AIResponse)
async def explain(payload: AIRequest, db: DbDep, user: CurrentUserDep) -> AIResponse:
    row = await create_ai_response(db, user, payload, "ai_explain")
    return AIResponse(id=row.id, result=row.explanation_text, created_at=row.created_at)


@router.post("/correct", response_model=AIResponse)
async def correct(payload: AIRequest, db: DbDep, user: CurrentUserDep) -> AIResponse:
    row = await create_ai_response(db, user, payload, "ai_correct")
    return AIResponse(id=row.id, result=row.explanation_text, created_at=row.created_at)


@router.post("/pronunciation-feedback", response_model=AIResponse)
async def pronunciation_feedback(payload: AIRequest, db: DbDep, user: CurrentUserDep) -> AIResponse:
    row = await create_ai_response(db, user, payload, "pronunciation_feedback")
    return AIResponse(id=row.id, result=row.explanation_text, created_at=row.created_at)


@router.get("/explanations/me")
async def explanations_me(db: DbDep, user: CurrentUserDep) -> dict:
    rows = await list_my_explanations(db, user)
    return {
        "items": [
            {
                "id": str(row.id),
                "source_type": row.source_type,
                "lesson_id": row.lesson_id,
                "question_id": str(row.question_id) if row.question_id else None,
                "explanation_text": row.explanation_text,
                "created_at": row.created_at.isoformat(),
            }
            for row in rows
        ]
    }
