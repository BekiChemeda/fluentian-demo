from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.user import UserMeResponse, UserProfileResponse, UserUpdateRequest
from app.services.user_service import build_user_profile

router = APIRouter(prefix="/user", tags=["user"])


@router.get("/me", response_model=UserMeResponse)
async def me(_: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> UserMeResponse:
    return UserMeResponse.model_validate(user)


@router.patch("/me", response_model=UserMeResponse)
async def update_me(
    payload: UserUpdateRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> UserMeResponse:
    if payload.native_language is not None:
        user.native_language = payload.native_language.strip() or user.native_language
    if payload.target_language is not None:
        user.target_language = payload.target_language.strip() or user.target_language
    if payload.daily_xp_goal is not None:
        user.daily_xp_goal = max(1, payload.daily_xp_goal)

    await db.commit()
    await db.refresh(user)
    return UserMeResponse.model_validate(user)


@router.get("/profile", response_model=UserProfileResponse)
async def profile(
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> UserProfileResponse:
    return await build_user_profile(db, user)
