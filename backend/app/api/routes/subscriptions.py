from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.subscription import SubscriptionResponse, UsageEventRequest, UsageEventResponse, UsageResponse
from app.services.usage_service import get_user_subscription, list_usage, record_usage_event

router = APIRouter(tags=["subscriptions"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.get("/subscriptions/me", response_model=SubscriptionResponse)
async def subscription_me(db: DbDep, user: CurrentUserDep) -> SubscriptionResponse:
    subscription, features = await get_user_subscription(db, user)
    return SubscriptionResponse(
        id=subscription.id if subscription else None,
        tier=subscription.tier if subscription else "free",
        status=subscription.status if subscription else "active",
        starts_at=subscription.starts_at if subscription else None,
        ends_at=subscription.ends_at if subscription else None,
        features=features,
    )


@router.get("/usage/me", response_model=UsageResponse)
async def usage_me(db: DbDep, user: CurrentUserDep) -> UsageResponse:
    rows = await list_usage(db, user)
    return UsageResponse(
        usage_date=date.today(),
        items=[
            {
                "feature_key": row.feature_key,
                "used_count": row.used_count,
                "limit_count": row.limit_count,
            }
            for row in rows
        ],
    )


@router.post("/usage/events", response_model=UsageEventResponse)
async def usage_event(payload: UsageEventRequest, db: DbDep, user: CurrentUserDep) -> UsageEventResponse:
    row = await record_usage_event(db, user, payload.feature_key, payload.quantity, payload.metadata)
    return UsageEventResponse(
        feature_key=row.feature_key,
        used_count=row.used_count,
        limit_count=row.limit_count,
        allowed=True,
    )
