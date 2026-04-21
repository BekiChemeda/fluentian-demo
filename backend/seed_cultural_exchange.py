import asyncio

from sqlalchemy import delete, select

from app.db.base import Base
from app.db.session import AsyncSessionLocal, engine
from app.models.cultural_topic import CulturalTopic
from app.services.community_service import DEFAULT_CULTURAL_TOPICS


async def seed() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as session:
        await session.execute(delete(CulturalTopic))
        await session.commit()

        session.add_all(
            [
                CulturalTopic(
                    title=item["title"],
                    subtitle=item["subtitle"],
                    hero_title=item["hero_title"],
                    image_placeholder=item["image_placeholder"],
                    cultural_cards=item["cultural_cards"],
                    starter_prompts=item["starter_prompts"],
                    order_index=item["order_index"],
                    active=True,
                )
                for item in DEFAULT_CULTURAL_TOPICS
            ]
        )
        await session.commit()

        result = await session.execute(select(CulturalTopic))
        print(f"Seeded {len(result.scalars().all())} cultural topics")


if __name__ == "__main__":
    asyncio.run(seed())
