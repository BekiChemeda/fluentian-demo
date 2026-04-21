import asyncio

from sqlalchemy import select

from app.core.security import hash_password
from app.db.base import Base
from app.db.session import engine
from app.db.session import AsyncSessionLocal
from app.models.user import User

SEED_EMAIL = "learner.am@fluentian.app"
SEED_PASSWORD = "Fluentian@123"


async def seed_user() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        result = await session.execute(select(User).where(User.email == SEED_EMAIL))
        user = result.scalar_one_or_none()

        if user is None:
            user = User(
                email=SEED_EMAIL,
                password_hash=hash_password(SEED_PASSWORD),
                native_language="Amharic",
                target_language="French",
                daily_xp_goal=20,
            )
            session.add(user)
            await session.commit()
            await session.refresh(user)
            print(f"Created user id={user.id} email={SEED_EMAIL}")
        else:
            user.password_hash = hash_password(SEED_PASSWORD)
            user.native_language = "Amharic"
            user.target_language = "French"
            user.daily_xp_goal = 20
            await session.commit()
            print(f"Updated existing user id={user.id} email={SEED_EMAIL}")


if __name__ == "__main__":
    asyncio.run(seed_user())
