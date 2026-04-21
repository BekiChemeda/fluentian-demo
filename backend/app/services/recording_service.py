from datetime import UTC, datetime, timedelta

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.models.call_recording import CallRecording
from app.models.rtc_session import RealtimeSession
from app.models.user import User


async def persist_session_recordings(db: AsyncSession, session: RealtimeSession) -> None:
    if not session.recording_url:
        return

    settings = get_settings()
    now = datetime.now(UTC)
    expires_at = now + timedelta(hours=settings.recording_retention_hours)

    rows = [
        CallRecording(
            session_id=session.id,
            owner_user_id=session.user_a_id,
            recording_url=session.recording_url,
            created_at=now,
            expires_at=expires_at,
            deleted=False,
        ),
        CallRecording(
            session_id=session.id,
            owner_user_id=session.user_b_id,
            recording_url=session.recording_url,
            created_at=now,
            expires_at=expires_at,
            deleted=False,
        ),
    ]
    db.add_all(rows)


async def list_user_recordings(db: AsyncSession, user: User, limit: int = 50) -> list[CallRecording]:
    now = datetime.now(UTC)
    result = await db.execute(
        select(CallRecording)
        .where(
            CallRecording.owner_user_id == user.id,
            CallRecording.deleted.is_(False),
            CallRecording.expires_at > now,
        )
        .order_by(CallRecording.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


async def get_session_recording(db: AsyncSession, user: User, session_id: int) -> CallRecording:
    now = datetime.now(UTC)
    result = await db.execute(
        select(CallRecording).where(
            CallRecording.owner_user_id == user.id,
            CallRecording.session_id == session_id,
            CallRecording.deleted.is_(False),
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        raise AppException("Recording not found", status_code=404, code="recording_not_found")
    if row.expires_at <= now:
        row.deleted = True
        await db.commit()
        raise AppException("Recording expired", status_code=410, code="recording_expired")
    return row


async def enforce_retention(db: AsyncSession) -> int:
    now = datetime.now(UTC)
    result = await db.execute(
        select(CallRecording).where(
            CallRecording.deleted.is_(False),
            CallRecording.expires_at <= now,
        )
    )
    rows = result.scalars().all()
    for row in rows:
        row.deleted = True
    if rows:
        await db.commit()
    return len(rows)
