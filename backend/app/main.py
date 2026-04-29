import asyncio
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from redis.exceptions import ConnectionError as RedisConnectionError

from app.api.router import api_router
from app.core.config import get_settings
from app.core.exceptions import register_exception_handlers
from app.core.middleware import RequestContextMiddleware, SimpleRateLimitMiddleware
from app.core.redis_client import get_redis_client
from app.db.base import Base
from app.db.session import AsyncSessionLocal, engine
from app.models import (
    BlockedUser,
    CallRecording,
    ChatMessage,
    CulturalTopic,
    DelfMockResult,
    DelfMockTest,
    DeviceToken,
    IdempotencyRecord,
    Lesson,
    MatchPair,
    MatchPresence,
    Progress,
    RealtimeSession,
    SessionReport,
    User,
    UserNotification,
    UserStats,
    Language,
    Course,
    CourseI18n,
    LearningPath,
    PathUnit,
    PathUnitI18n,
    UnitLesson,
    LessonBlockRecord,
    Question,
    UserQuestionAttempt,
    UserLessonProgress,
    ReviewQueueItem,
    AIExplanation,
    SubscriptionPlan,
    PlanFeature,
    UserSubscription,
    UserDailyUsage,
    UsageEvent,
    Payment,
    PaymentTransaction,
    TutorProfile,
    TutorAvailability,
    TutorBooking,
    OpportunityCategory,
    Opportunity,
    SavedOpportunity,
    OpportunityGuidanceRequest,
    ModerationFlag,
    AuditLog,
)
from app.services.recording_service import enforce_retention
from app.services.realtime_service import process_matchmaking_once, sweep_inactive_queue_users

settings = get_settings()


async def _ensure_sqlite_user_columns() -> None:
    if not settings.database_url.startswith("sqlite"):
        return

    async with engine.begin() as conn:
        result = await conn.exec_driver_sql("PRAGMA table_info(users)")
        existing_columns = {row[1] for row in result.fetchall()}
        required_columns = {
            "cefr_level": "ALTER TABLE users ADD COLUMN cefr_level VARCHAR(8) NOT NULL DEFAULT 'A1'",
            "role": "ALTER TABLE users ADD COLUMN role VARCHAR(24) NOT NULL DEFAULT 'student'",
            "learning_intent": "ALTER TABLE users ADD COLUMN learning_intent VARCHAR(64) NOT NULL DEFAULT 'casual'",
            "preferred_mode": "ALTER TABLE users ADD COLUMN preferred_mode VARCHAR(16) NOT NULL DEFAULT 'text'",
            "report_count": "ALTER TABLE users ADD COLUMN report_count INTEGER NOT NULL DEFAULT 0",
            "drop_rate": "ALTER TABLE users ADD COLUMN drop_rate FLOAT NOT NULL DEFAULT 0.0",
            "avg_session_duration_seconds": "ALTER TABLE users ADD COLUMN avg_session_duration_seconds INTEGER NOT NULL DEFAULT 0",
        }

        for column_name, ddl in required_columns.items():
            if column_name not in existing_columns:
                await conn.execute(text(ddl))


async def _ensure_sqlite_lesson_columns() -> None:
    if not settings.database_url.startswith("sqlite"):
        return

    async with engine.begin() as conn:
        result = await conn.exec_driver_sql("PRAGMA table_info(lessons)")
        existing_columns = {row[1] for row in result.fetchall()}
        required_columns = {
            "course_id": "ALTER TABLE lessons ADD COLUMN course_id CHAR(32)",
            "lesson_kind": "ALTER TABLE lessons ADD COLUMN lesson_kind VARCHAR(40)",
            "is_published": "ALTER TABLE lessons ADD COLUMN is_published BOOLEAN NOT NULL DEFAULT 1",
            "created_by": "ALTER TABLE lessons ADD COLUMN created_by INTEGER",
            "updated_by": "ALTER TABLE lessons ADD COLUMN updated_by INTEGER",
            "published_at": "ALTER TABLE lessons ADD COLUMN published_at DATETIME",
            "archived_at": "ALTER TABLE lessons ADD COLUMN archived_at DATETIME",
            "created_at": "ALTER TABLE lessons ADD COLUMN created_at DATETIME",
            "updated_at": "ALTER TABLE lessons ADD COLUMN updated_at DATETIME",
        }

        for column_name, ddl in required_columns.items():
            if column_name not in existing_columns:
                await conn.execute(text(ddl))


async def _matchmaking_loop() -> None:
    while True:
        try:
            async with AsyncSessionLocal() as db:
                await enforce_retention(db)
            await sweep_inactive_queue_users(settings.heartbeat_timeout_seconds)
            async with AsyncSessionLocal() as db:
                await process_matchmaking_once(db)
        except Exception:
            # Keep the loop resilient; failures should not take down the API server.
            pass
        await asyncio.sleep(settings.matchmaking_loop_interval_seconds)


@asynccontextmanager
async def lifespan(_: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    await _ensure_sqlite_user_columns()
    await _ensure_sqlite_lesson_columns()

    loop_task: asyncio.Task | None = None
    if settings.matchmaking_loop_enabled:
        loop_task = asyncio.create_task(_matchmaking_loop())

    try:
        yield
    finally:
        if loop_task is not None:
            loop_task.cancel()
        redis = get_redis_client()
        await redis.aclose()


app = FastAPI(title=settings.app_name, lifespan=lifespan)
register_exception_handlers(app)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(SimpleRateLimitMiddleware)
app.add_middleware(RequestContextMiddleware)

app.include_router(api_router)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.get("/health/ready")
async def readiness() -> dict[str, str]:
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))

    try:
        redis = get_redis_client()
        await redis.ping()
        return {"status": "ready"}
    except (RedisConnectionError, RuntimeError):
        return {"status": "degraded", "redis": "unavailable"}
