from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import delete, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.opportunity import Opportunity, OpportunityGuidanceRequest, SavedOpportunity
from app.models.user import User
from app.schemas.opportunity import GuidanceRequest, OpportunityCreateRequest, OpportunityUpdateRequest
from app.services.community_service import generate_with_gemini


async def list_opportunities(
    db: AsyncSession,
    user: User,
    page: int,
    page_size: int,
) -> tuple[list[Opportunity], int]:
    stmt = select(Opportunity).where(Opportunity.archived_at.is_(None))
    if user.role not in {"admin", "moderator"}:
        stmt = stmt.where(Opportunity.is_published.is_(True))
    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    result = await db.execute(stmt.order_by(Opportunity.deadline_at.is_(None), Opportunity.deadline_at).offset((page - 1) * page_size).limit(page_size))
    return list(result.scalars().all()), int(total or 0)


async def get_opportunity(db: AsyncSession, user: User, opportunity_id: UUID) -> Opportunity:
    row = await db.get(Opportunity, opportunity_id)
    if row is None or row.archived_at is not None:
        raise AppException("Opportunity not found", status_code=404, code="opportunity_not_found")
    if not row.is_published and user.role not in {"admin", "moderator"}:
        raise AppException("Opportunity not found", status_code=404, code="opportunity_not_found")
    return row


async def create_opportunity(db: AsyncSession, actor: User, payload: OpportunityCreateRequest) -> Opportunity:
    _require_admin(actor)
    now = datetime.now(UTC)
    row = Opportunity(
        **payload.model_dump(),
        created_by=actor.id,
        updated_by=actor.id,
        published_at=now if payload.is_published else None,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def update_opportunity(
    db: AsyncSession,
    actor: User,
    opportunity_id: UUID,
    payload: OpportunityUpdateRequest,
) -> Opportunity:
    _require_admin(actor)
    row = await db.get(Opportunity, opportunity_id)
    if row is None or row.archived_at is not None:
        raise AppException("Opportunity not found", status_code=404, code="opportunity_not_found")
    now = datetime.now(UTC)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(row, key, value)
    if payload.is_published and row.published_at is None:
        row.published_at = now
    row.updated_by = actor.id
    row.updated_at = now
    await db.commit()
    await db.refresh(row)
    return row


async def archive_opportunity(db: AsyncSession, actor: User, opportunity_id: UUID) -> None:
    _require_admin(actor)
    row = await db.get(Opportunity, opportunity_id)
    if row is None or row.archived_at is not None:
        raise AppException("Opportunity not found", status_code=404, code="opportunity_not_found")
    now = datetime.now(UTC)
    row.archived_at = now
    row.updated_by = actor.id
    row.updated_at = now
    await db.commit()


async def save_opportunity(db: AsyncSession, user: User, opportunity_id: UUID) -> None:
    await get_opportunity(db, user, opportunity_id)
    existing = await db.execute(
        select(SavedOpportunity).where(SavedOpportunity.user_id == user.id, SavedOpportunity.opportunity_id == opportunity_id)
    )
    if existing.scalar_one_or_none() is None:
        db.add(SavedOpportunity(user_id=user.id, opportunity_id=opportunity_id, created_at=datetime.now(UTC)))
        await db.commit()


async def unsave_opportunity(db: AsyncSession, user: User, opportunity_id: UUID) -> None:
    await db.execute(
        delete(SavedOpportunity).where(SavedOpportunity.user_id == user.id, SavedOpportunity.opportunity_id == opportunity_id)
    )
    await db.commit()


async def request_guidance(
    db: AsyncSession,
    user: User,
    opportunity_id: UUID,
    payload: GuidanceRequest,
) -> OpportunityGuidanceRequest:
    opportunity = await get_opportunity(db, user, opportunity_id)
    prompt = (
        f"Advise a French learner whose base language is {user.native_language}. "
        f"Opportunity: {opportunity.title} by {opportunity.provider_name}. "
        f"Question: {payload.question}. Keep guidance practical."
    )
    try:
        answer = await generate_with_gemini(prompt, temperature=0.2, max_output_tokens=420)
    except Exception:
        answer = "Focus on eligibility, deadline, required documents, and the French level expected before applying."
    row = OpportunityGuidanceRequest(
        user_id=user.id,
        opportunity_id=opportunity_id,
        question=payload.question,
        ai_response=answer,
        created_at=datetime.now(UTC),
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


def _require_admin(user: User) -> None:
    if user.role != "admin":
        raise AppException("Admin permission required", status_code=403, code="forbidden")
