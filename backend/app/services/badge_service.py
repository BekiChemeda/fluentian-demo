from datetime import date

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.progress import Progress
from app.models.user import User
from app.schemas.badge import BadgeListResponse, BadgeResponse

_DEFAULT_BADGE_SVG = (
    "<svg viewBox='0 0 24 24' xmlns='http://www.w3.org/2000/svg'>"
    "<path fill='#35B95E' d='M12 2l3.1 6.2L22 9l-5 4.6L18.2 22 12 18.7 5.8 22 7 13.6 2 9l6.9-.8L12 2z'/>"
    "</svg>"
)


async def get_badges(db: AsyncSession, user: User) -> BadgeListResponse:
    progress_result = await db.execute(select(Progress).where(Progress.user_id == user.id, Progress.completed.is_(True)))
    completed_lessons = progress_result.scalars().all()
    completed_count = len(completed_lessons)

    streak_date = user.last_active_date.isoformat() if isinstance(user.last_active_date, date) else None

    badges = [
        BadgeResponse(
            id=1,
            name="First Lesson",
            description="Complete your first lesson.",
            unlocked=completed_count >= 1,
            unlock_date=streak_date if completed_count >= 1 else None,
            unlock_criteria="Complete 1 lesson",
            icon_svg=_DEFAULT_BADGE_SVG,
        ),
        BadgeResponse(
            id=2,
            name="Five Lessons",
            description="Build momentum by finishing five lessons.",
            unlocked=completed_count >= 5,
            unlock_date=streak_date if completed_count >= 5 else None,
            unlock_criteria="Complete 5 lessons",
            icon_svg=_DEFAULT_BADGE_SVG,
        ),
        BadgeResponse(
            id=3,
            name="7-Day Streak",
            description="Maintain your learning streak for seven days.",
            unlocked=user.streak >= 7,
            unlock_date=streak_date if user.streak >= 7 else None,
            unlock_criteria="Reach a 7 day streak",
            icon_svg=_DEFAULT_BADGE_SVG,
        ),
        BadgeResponse(
            id=4,
            name="XP Hunter",
            description="Earn your first 100 XP.",
            unlocked=user.xp >= 100,
            unlock_date=streak_date if user.xp >= 100 else None,
            unlock_criteria="Reach 100 XP",
            icon_svg=_DEFAULT_BADGE_SVG,
        ),
    ]

    return BadgeListResponse(items=badges)
