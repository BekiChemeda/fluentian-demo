from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.progress import ProgressResponse
from app.services.progress_service import get_progress

router = APIRouter(prefix="/progress", tags=["progress"])


@router.get("", response_model=ProgressResponse)
async def progress(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> ProgressResponse:
    return await get_progress(db, user)
