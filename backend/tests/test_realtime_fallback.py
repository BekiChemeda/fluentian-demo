import asyncio
import time

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.deps import get_current_user
from app.db.base import Base
from app.db.session import AsyncSessionLocal, engine
from app.main import app
from app.models.user import User


def test_queue_join_works_without_redis():
    async def seed_user() -> int:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with AsyncSessionLocal() as db:
            suffix = int(time.time() * 1000)
            user = User(email=f"queue_{suffix}@example.com", password_hash="x")
            db.add(user)
            await db.commit()
            return user.id

    user_id = asyncio.run(seed_user())

    async def override_current_user() -> User:
        async with AsyncSessionLocal() as db:
            result = await db.execute(select(User).where(User.id == user_id))
            return result.scalar_one()

    app.dependency_overrides[get_current_user] = override_current_user
    try:
        client = TestClient(app)
        response = client.post(
            "/queue/join",
            json={
                "preferred_mode": "text",
                "learning_intent": "casual",
                "cefr_level": "A1",
                "recording_consent": False,
            },
        )
        assert response.status_code == 200
        assert response.json()["status"] == "queued"

        ready = client.get("/health/ready")
        assert ready.status_code == 200
        assert ready.json()["status"] in {"ready", "degraded"}
    finally:
        app.dependency_overrides.clear()