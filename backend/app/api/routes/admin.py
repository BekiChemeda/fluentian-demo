from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.moderation import ModerationFlagListResponse, ModerationFlagResponse, ModerationFlagUpdateRequest
from app.services.moderation_service import list_flags, update_flag

router = APIRouter(prefix="/admin", tags=["admin"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.get("/moderation-flags", response_model=ModerationFlagListResponse)
async def moderation_flags(
    db: DbDep,
    user: CurrentUserDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> ModerationFlagListResponse:
    items, total = await list_flags(db, user, page, page_size)
    return ModerationFlagListResponse(items=items, page=page, page_size=page_size, total=total)


@router.patch("/moderation-flags/{flag_id}", response_model=ModerationFlagResponse)
async def update_moderation_flag(
    flag_id: UUID,
    payload: ModerationFlagUpdateRequest,
    db: DbDep,
    user: CurrentUserDep,
) -> ModerationFlagResponse:
    return ModerationFlagResponse.model_validate(await update_flag(db, user, flag_id, payload))
