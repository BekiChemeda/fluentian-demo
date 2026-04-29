from datetime import UTC, date, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.subscription import PlanFeature, SubscriptionPlan, UsageEvent, UserDailyUsage, UserSubscription
from app.models.user import User


async def get_user_subscription(db: AsyncSession, user: User) -> tuple[UserSubscription | None, dict[str, int | None]]:
    subscription_result = await db.execute(
        select(UserSubscription)
        .where(UserSubscription.user_id == user.id, UserSubscription.status == "active")
        .order_by(UserSubscription.created_at.desc())
        .limit(1)
    )
    subscription = subscription_result.scalar_one_or_none()

    tier = subscription.tier if subscription else "free"
    plan_stmt = select(SubscriptionPlan).where(SubscriptionPlan.tier == tier, SubscriptionPlan.is_active.is_(True))
    if subscription and subscription.plan_id:
        plan_stmt = select(SubscriptionPlan).where(SubscriptionPlan.id == subscription.plan_id)
    plan_result = await db.execute(plan_stmt.limit(1))
    plan = plan_result.scalar_one_or_none()
    if plan is None:
        return subscription, {}

    feature_result = await db.execute(select(PlanFeature).where(PlanFeature.plan_id == plan.id))
    return subscription, {feature.feature_key: feature.limit_per_day for feature in feature_result.scalars().all()}


async def record_usage_event(
    db: AsyncSession,
    user: User,
    feature_key: str,
    quantity: int = 1,
    metadata: dict | None = None,
    enforce_limit: bool = True,
) -> UserDailyUsage:
    today = date.today()
    _, features = await get_user_subscription(db, user)
    limit_count = features.get(feature_key)

    usage_result = await db.execute(
        select(UserDailyUsage).where(
            UserDailyUsage.user_id == user.id,
            UserDailyUsage.usage_date == today,
            UserDailyUsage.feature_key == feature_key,
        )
    )
    usage = usage_result.scalar_one_or_none()
    now = datetime.now(UTC)
    if usage is None:
        usage = UserDailyUsage(
            user_id=user.id,
            usage_date=today,
            feature_key=feature_key,
            used_count=0,
            limit_count=limit_count,
            updated_at=now,
        )
        db.add(usage)

    if enforce_limit and limit_count is not None and usage.used_count + quantity > limit_count:
        raise AppException("Usage limit exceeded", status_code=402, code="usage_limit_exceeded")

    usage.used_count += quantity
    usage.limit_count = limit_count
    usage.updated_at = now
    db.add(UsageEvent(user_id=user.id, feature_key=feature_key, quantity=quantity, metadata=metadata, created_at=now))
    await db.commit()
    await db.refresh(usage)
    return usage


async def list_usage(db: AsyncSession, user: User) -> list[UserDailyUsage]:
    today = date.today()
    result = await db.execute(
        select(UserDailyUsage)
        .where(UserDailyUsage.user_id == user.id, UserDailyUsage.usage_date == today)
        .order_by(UserDailyUsage.feature_key)
    )
    return list(result.scalars().all())


async def count_rows(db: AsyncSession, stmt) -> int:
    result = await db.execute(select(func.count()).select_from(stmt.subquery()))
    return int(result.scalar_one())
