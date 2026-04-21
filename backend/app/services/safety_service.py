from datetime import UTC, datetime

from sqlalchemy import and_, delete, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.blocked_user import BlockedUser
from app.models.user import User


async def is_user_blocked_pair(db: AsyncSession, user_a_id: int, user_b_id: int) -> bool:
    result = await db.execute(
        select(BlockedUser.id).where(
            or_(
                and_(BlockedUser.blocker_user_id == user_a_id, BlockedUser.blocked_user_id == user_b_id),
                and_(BlockedUser.blocker_user_id == user_b_id, BlockedUser.blocked_user_id == user_a_id),
            )
        )
    )
    return result.scalar_one_or_none() is not None


async def block_user(db: AsyncSession, actor: User, target_user_id: int, reason: str) -> BlockedUser:
    if target_user_id == actor.id:
        raise AppException("You cannot block yourself", status_code=400, code="invalid_block_target")

    target_result = await db.execute(select(User).where(User.id == target_user_id))
    target_user = target_result.scalar_one_or_none()
    if target_user is None:
        raise AppException("User not found", status_code=404, code="user_not_found")

    existing = await db.execute(
        select(BlockedUser).where(
            BlockedUser.blocker_user_id == actor.id,
            BlockedUser.blocked_user_id == target_user_id,
        )
    )
    row = existing.scalar_one_or_none()
    if row is not None:
        if reason:
            row.reason = reason
        await db.commit()
        await db.refresh(row)
        return row

    row = BlockedUser(
        blocker_user_id=actor.id,
        blocked_user_id=target_user_id,
        reason=reason,
        created_at=datetime.now(UTC),
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def unblock_user(db: AsyncSession, actor: User, target_user_id: int) -> None:
    await db.execute(
        delete(BlockedUser).where(
            BlockedUser.blocker_user_id == actor.id,
            BlockedUser.blocked_user_id == target_user_id,
        )
    )
    await db.commit()


async def list_blocked_users(db: AsyncSession, actor: User) -> list[BlockedUser]:
    result = await db.execute(
        select(BlockedUser)
        .where(BlockedUser.blocker_user_id == actor.id)
        .order_by(BlockedUser.created_at.desc())
    )
    return result.scalars().all()
