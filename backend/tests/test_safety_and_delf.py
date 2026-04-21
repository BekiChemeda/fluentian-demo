import asyncio
import json
import time

from fastapi.testclient import TestClient
from sqlalchemy import select

from app.api.deps import get_current_user
from app.db.base import Base
from app.db.session import AsyncSessionLocal
from app.db.session import engine
from app.main import app
from app.models.delf import DelfMockTest
from app.models.user import User


def _seed_users_and_delf() -> tuple[int, int]:
    async def _seed() -> tuple[int, int]:
        suffix = int(time.time() * 1000)
        actor_email = f"actor_{suffix}@example.com"
        target_email = f"target_{suffix}@example.com"

        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)

        async with AsyncSessionLocal() as db:
            actor = User(email=actor_email, password_hash="x")
            target = User(email=target_email, password_hash="x")
            db.add_all([actor, target])
            await db.flush()

            test = DelfMockTest(
                title="DELF A1 Basics",
                level="A1",
                description="Intro mock for regression tests",
                questions_json=json.dumps(
                    [
                        {
                            "id": 1,
                            "prompt": "Bonjour means?",
                            "choices": ["Hello", "Goodbye"],
                            "correct_index": 0,
                        }
                    ]
                ),
                passing_score=70,
            )
            db.add(test)
            await db.commit()
            return actor.id, target.id

    return asyncio.run(_seed())


def test_delf_tests_returns_seeded_item():
    actor_id, _ = _seed_users_and_delf()

    async def override_current_user() -> User:
        async with AsyncSessionLocal() as db:
            result = await db.execute(select(User).where(User.id == actor_id))
            user = result.scalar_one()
            return user

    app.dependency_overrides[get_current_user] = override_current_user
    try:
        client = TestClient(app)
        response = client.get("/delf/tests")
        assert response.status_code == 200
        items = response.json()
        assert isinstance(items, list)
        assert any(item.get("title") == "DELF A1 Basics" for item in items)
    finally:
        app.dependency_overrides.clear()


def test_block_and_unblock_flow():
    actor_id, target_id = _seed_users_and_delf()

    async def override_current_user() -> User:
        async with AsyncSessionLocal() as db:
            result = await db.execute(select(User).where(User.id == actor_id))
            user = result.scalar_one()
            return user

    app.dependency_overrides[get_current_user] = override_current_user
    try:
        client = TestClient(app)

        block_response = client.post(
            "/safety/block",
            json={"user_id": target_id, "reason": "abuse"},
        )
        assert block_response.status_code == 200
        assert block_response.json()["user_id"] == target_id

        list_response = client.get("/safety/blocked")
        assert list_response.status_code == 200
        blocked_ids = [item["user_id"] for item in list_response.json().get("items", [])]
        assert target_id in blocked_ids

        unblock_response = client.delete(f"/safety/block/{target_id}")
        assert unblock_response.status_code == 200
        assert unblock_response.json()["status"] == "ok"
    finally:
        app.dependency_overrides.clear()