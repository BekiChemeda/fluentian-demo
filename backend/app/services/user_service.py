from math import ceil

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.lesson import Lesson
from app.models.progress import Progress
from app.models.user import User
from app.schemas.user import BadgeResponse, UnitProgressResponse, UserProfileResponse


def _default_badge_svg(fill: str) -> str:
    return (
        "<svg viewBox='0 0 24 24' xmlns='http://www.w3.org/2000/svg'>"
        f"<path fill='{fill}' d='M12 2l3 6h7l-5 5 2 9-7-4-7 4 2-9-5-5h7z'/>"
        "</svg>"
    )


async def build_user_profile(db: AsyncSession, user: User) -> UserProfileResponse:
    lesson_result = await db.execute(select(Lesson).order_by(Lesson.order_index))
    lessons = lesson_result.scalars().all()

    progress_result = await db.execute(select(Progress).where(Progress.user_id == user.id))
    progress_map = {p.lesson_id: p for p in progress_result.scalars().all()}

    unit_size = 5
    units_progress: list[UnitProgressResponse] = []

    for i in range(0, len(lessons), unit_size):
        chunk = lessons[i : i + unit_size]
        if not chunk:
            continue

        completed_count = sum(
            1
            for lesson in chunk
            if lesson.id in progress_map and progress_map[lesson.id].completed
        )
        ratio = completed_count / len(chunk)
        unit_id = (i // unit_size) + 1

        units_progress.append(
            UnitProgressResponse(
                unit_id=unit_id,
                unit_title=f"Unit {unit_id}",
                completion_percentage=round(ratio, 3),
            )
        )

    completed_lessons = sum(1 for progress in progress_map.values() if progress.completed)
    completed_units = sum(1 for unit in units_progress if unit.completion_percentage >= 1)

    level = (user.xp // 100) + 1
    level_target_xp = level * 100
    daily_goal = max(1, user.daily_xp_goal)
    today_xp = min(daily_goal, user.xp % daily_goal)
    next_milestone_xp = ceil((user.xp + 1) / 100) * 100

    username = user.email.split("@")[0].strip() or "learner"
    unlocked_date = user.last_active_date.isoformat() if user.last_active_date else None

    badges = [
        BadgeResponse(
            id=1,
            name="7-Day Flame",
            description="Keep your streak alive for 7 days.",
            unlocked=user.streak >= 7,
            unlock_date=unlocked_date if user.streak >= 7 else None,
            unlock_criteria="Maintain a 7 day streak",
            icon_svg=_default_badge_svg("#F39A2E"),
        ),
        BadgeResponse(
            id=2,
            name="XP Hunter",
            description="Earn 300 XP total.",
            unlocked=user.xp >= 300,
            unlock_date=unlocked_date if user.xp >= 300 else None,
            unlock_criteria="Reach 300 total XP",
            icon_svg=_default_badge_svg("#35B95E"),
        ),
        BadgeResponse(
            id=3,
            name="Lesson Runner",
            description="Complete 5 lessons.",
            unlocked=completed_lessons >= 5,
            unlock_date=unlocked_date if completed_lessons >= 5 else None,
            unlock_criteria="Complete 5 lessons",
            icon_svg=_default_badge_svg("#5B9BD8"),
        ),
        BadgeResponse(
            id=4,
            name="Unit Crusher",
            description="Fully complete one unit.",
            unlocked=completed_units >= 1,
            unlock_date=unlocked_date if completed_units >= 1 else None,
            unlock_criteria="Complete all lessons in one unit",
            icon_svg=_default_badge_svg("#8B63D2"),
        ),
    ]

    return UserProfileResponse(
        id=user.id,
        username=username,
        email=user.email,
        native_language=user.native_language,
        target_language=user.target_language,
        level=level,
        current_xp=user.xp,
        level_target_xp=level_target_xp,
        streak=user.streak,
        daily_goal=daily_goal,
        today_xp=today_xp,
        total_xp=user.xp,
        next_milestone_xp=next_milestone_xp,
        units_progress=units_progress,
        badges=badges,
    )
