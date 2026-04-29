from fastapi import APIRouter

from app.api.routes import (
    admin,
    ai,
    auth,
    badges,
    community,
    delf,
    lessons,
    notifications,
    opportunities,
    platform,
    progress,
    realtime,
    recordings,
    safety,
    subscriptions,
    tutors,
    user,
)

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(user.router)
api_router.include_router(platform.router)
api_router.include_router(lessons.router)
api_router.include_router(progress.router)
api_router.include_router(ai.router)
api_router.include_router(subscriptions.router)
api_router.include_router(tutors.router)
api_router.include_router(opportunities.router)
api_router.include_router(admin.router)
api_router.include_router(badges.router)
api_router.include_router(community.router)
api_router.include_router(realtime.router)
api_router.include_router(safety.router)
api_router.include_router(notifications.router)
api_router.include_router(delf.router)
api_router.include_router(recordings.router)
