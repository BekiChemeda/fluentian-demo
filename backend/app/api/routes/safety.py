from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.safety import BlockedUserListResponse, BlockedUserResponse, BlockUserRequest
from app.services.safety_service import block_user, list_blocked_users, unblock_user

router = APIRouter(prefix="/safety", tags=["safety"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.post("/block", response_model=BlockedUserResponse)
async def block(payload: BlockUserRequest, db: DbDep, user: CurrentUserDep) -> BlockedUserResponse:
    row = await block_user(db, user, payload.user_id, payload.reason)
    return BlockedUserResponse(user_id=row.blocked_user_id, reason=row.reason, created_at=row.created_at)


@router.delete("/block/{target_user_id}")
async def unblock(target_user_id: int, db: DbDep, user: CurrentUserDep) -> dict[str, str]:
    await unblock_user(db, user, target_user_id)
    return {"status": "ok"}


@router.get("/blocked", response_model=BlockedUserListResponse)
async def blocked_list(db: DbDep, user: CurrentUserDep) -> BlockedUserListResponse:
    rows = await list_blocked_users(db, user)
    return BlockedUserListResponse(
        items=[
            BlockedUserResponse(user_id=row.blocked_user_id, reason=row.reason, created_at=row.created_at)
            for row in rows
        ]
    )
