import json
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.notification import (
    DeviceTokenUpsertRequest,
    NotificationItemResponse,
    NotificationListResponse,
    NotificationReadRequest,
    NotificationReadResponse,
)
from app.services.notification_service import list_notifications, mark_notifications_read, register_device_token

router = APIRouter(prefix="/notifications", tags=["notifications"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.post("/device-token")
async def upsert_device_token(payload: DeviceTokenUpsertRequest, db: DbDep, user: CurrentUserDep) -> dict[str, str]:
    await register_device_token(db, user, payload)
    return {"status": "ok"}


@router.get("", response_model=NotificationListResponse)
async def list_user_notifications(
    db: DbDep,
    user: CurrentUserDep,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> NotificationListResponse:
    rows = await list_notifications(db, user, limit=limit)
    items = [
        NotificationItemResponse(
            id=row.id,
            type=row.type,
            title=row.title,
            body=row.body,
            metadata=json.loads(row.metadata_json),
            is_read=row.is_read,
            created_at=row.created_at,
        )
        for row in rows
    ]
    return NotificationListResponse(items=items)


@router.post("/read", response_model=NotificationReadResponse)
async def read_notifications(payload: NotificationReadRequest, db: DbDep, user: CurrentUserDep) -> NotificationReadResponse:
    updated = await mark_notifications_read(db, user, payload)
    return NotificationReadResponse(updated=updated)
