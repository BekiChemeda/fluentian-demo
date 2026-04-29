from collections.abc import AsyncGenerator

from sqlalchemy import event
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.core.config import get_settings

settings = get_settings()

engine = create_async_engine(settings.database_url, pool_pre_ping=True)
AsyncSessionLocal = async_sessionmaker(bind=engine, class_=AsyncSession, expire_on_commit=False)


@event.listens_for(engine.sync_engine, "connect")
def _ensure_sqlite_compat_columns(dbapi_connection, _: object) -> None:
    if not settings.database_url.startswith("sqlite"):
        return

    cursor = dbapi_connection.cursor()
    try:
        cursor.execute("PRAGMA table_info(users)")
        user_columns = {row[1] for row in cursor.fetchall()}
        if user_columns and "role" not in user_columns:
            cursor.execute("ALTER TABLE users ADD COLUMN role VARCHAR(24) NOT NULL DEFAULT 'student'")

        cursor.execute("PRAGMA table_info(lessons)")
        lesson_columns = {row[1] for row in cursor.fetchall()}
        lesson_columns_to_add = {
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
        if lesson_columns:
            for column_name, ddl in lesson_columns_to_add.items():
                if column_name not in lesson_columns:
                    cursor.execute(ddl)
        dbapi_connection.commit()
    finally:
        cursor.close()


async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        yield session
