from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.progress import Progress
from app.models.user import User
from app.schemas.progress import ProgressItem, ProgressResponse


async def get_progress(db: AsyncSession, user: User) -> ProgressResponse:
    result = await db.execute(select(Progress).where(Progress.user_id == user.id))
    rows = result.scalars().all()
    return ProgressResponse(
        items=[ProgressItem(lesson_id=row.lesson_id, completed=row.completed, score=row.score) for row in rows]
    )
