from fastapi import APIRouter

from app.api.routes import auth, badges, community, delf, lessons, notifications, progress, realtime, recordings, safety, user

api_router = APIRouter()
api_router.include_router(auth.router)
api_router.include_router(user.router)
api_router.include_router(lessons.router)
api_router.include_router(progress.router)
api_router.include_router(badges.router)
api_router.include_router(community.router)
api_router.include_router(realtime.router)
api_router.include_router(safety.router)
api_router.include_router(notifications.router)
api_router.include_router(delf.router)
api_router.include_router(recordings.router)
