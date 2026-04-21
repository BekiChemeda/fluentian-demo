import json
from datetime import UTC, datetime

import httpx
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.models.notification import DeviceToken, UserNotification
from app.models.user import User
from app.schemas.notification import DeviceTokenUpsertRequest, NotificationReadRequest


async def register_device_token(db: AsyncSession, user: User, payload: DeviceTokenUpsertRequest) -> None:
    existing_result = await db.execute(
        select(DeviceToken).where(
            DeviceToken.user_id == user.id,
            DeviceToken.token == payload.token,
        )
    )
    existing = existing_result.scalar_one_or_none()
    now = datetime.now(UTC)

    if existing:
        existing.active = True
        existing.platform = payload.platform
        existing.updated_at = now
    else:
        db.add(
            DeviceToken(
                user_id=user.id,
                token=payload.token,
                platform=payload.platform,
                active=True,
                created_at=now,
                updated_at=now,
            )
        )

    await db.commit()


async def create_notification(
    db: AsyncSession,
    *,
    user_id: int,
    event_type: str,
    title: str,
    body: str,
    metadata: dict | None = None,
    commit: bool = True,
) -> UserNotification:
    row = UserNotification(
        user_id=user_id,
        type=event_type,
        title=title,
        body=body,
        metadata_json=json.dumps(metadata or {}, separators=(",", ":")),
        is_read=False,
        created_at=datetime.now(UTC),
    )
    db.add(row)
    if commit:
        await db.commit()
        await db.refresh(row)
        await _send_push_best_effort(db, row)
    return row


async def list_notifications(db: AsyncSession, user: User, limit: int = 50) -> list[UserNotification]:
    result = await db.execute(
        select(UserNotification)
        .where(UserNotification.user_id == user.id)
        .order_by(UserNotification.created_at.desc())
        .limit(limit)
    )
    return result.scalars().all()


async def mark_notifications_read(db: AsyncSession, user: User, payload: NotificationReadRequest) -> int:
    now = datetime.now(UTC)
    if payload.mark_all:
        stmt = (
            update(UserNotification)
            .where(UserNotification.user_id == user.id, UserNotification.is_read.is_(False))
            .values(is_read=True, read_at=now)
        )
    elif payload.notification_ids:
        stmt = (
            update(UserNotification)
            .where(
                UserNotification.user_id == user.id,
                UserNotification.id.in_(payload.notification_ids),
            )
            .values(is_read=True, read_at=now)
        )
    else:
        return 0

    result = await db.execute(stmt)
    await db.commit()
    return int(result.rowcount or 0)


async def _send_push_best_effort(db: AsyncSession, notification: UserNotification) -> None:
    settings = get_settings()
    api_key = getattr(settings, "fcm_server_key", None)
    if not api_key:
        return

    token_result = await db.execute(
        select(DeviceToken.token).where(
            DeviceToken.user_id == notification.user_id,
            DeviceToken.active.is_(True),
        )
    )
    tokens = [row[0] for row in token_result.fetchall()]
    if not tokens:
        return

    payload = {
        "registration_ids": tokens,
        "notification": {
            "title": notification.title,
            "body": notification.body,
        },
        "data": {
            "type": notification.type,
            "notification_id": str(notification.id),
        },
        "priority": "high",
    }

    headers = {
        "Authorization": f"key={api_key}",
        "Content-Type": "application/json",
    }

    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            await client.post("https://fcm.googleapis.com/fcm/send", json=payload, headers=headers)
    except Exception:
        # Notification persistence is primary; push delivery is best-effort.
        return
