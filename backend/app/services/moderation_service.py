from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.moderation import ModerationFlag
from app.models.user import User
from app.schemas.moderation import ModerationFlagUpdateRequest


async def list_flags(db: AsyncSession, actor: User, page: int, page_size: int) -> tuple[list[ModerationFlag], int]:
    _require_reviewer(actor)
    stmt = select(ModerationFlag)
    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    result = await db.execute(
        stmt.order_by(ModerationFlag.status, ModerationFlag.severity.desc(), ModerationFlag.created_at.desc())
        .offset((page - 1) * page_size)
        .limit(page_size)
    )
    return list(result.scalars().all()), int(total or 0)


async def update_flag(
    db: AsyncSession,
    actor: User,
    flag_id: UUID,
    payload: ModerationFlagUpdateRequest,
) -> ModerationFlag:
    _require_reviewer(actor)
    row = await db.get(ModerationFlag, flag_id)
    if row is None:
        raise AppException("Moderation flag not found", status_code=404, code="moderation_flag_not_found")
    row.status = payload.status
    row.resolution_note = payload.resolution_note
    if payload.status in {"resolved", "dismissed", "closed"} and row.resolved_at is None:
        row.resolved_at = datetime.now(UTC)
    await db.commit()
    await db.refresh(row)
    return row


def _require_reviewer(user: User) -> None:
    if user.role not in {"admin", "moderator"}:
        raise AppException("Moderator permission required", status_code=403, code="forbidden")
