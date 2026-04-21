from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.badge import BadgeListResponse
from app.services.badge_service import get_badges

router = APIRouter(prefix="/badges", tags=["badges"])


@router.get("", response_model=BadgeListResponse)
async def badges(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> BadgeListResponse:
    return await get_badges(db, user)
