import asyncio
from datetime import UTC, datetime

from sqlalchemy import select

from app.db.session import AsyncSessionLocal, engine
from app.db.base import Base
from app.models.learning_schema import (
    Course,
    CourseI18n,
    Language,
    LearningPath,
    PathUnit,
    PathUnitI18n,
    Question,
    UnitLesson,
)
from app.models.lesson import Lesson
from app.models.subscription import PlanFeature, SubscriptionPlan


async def main() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        now = datetime.now(UTC)

        languages = [
            ("fr", "French", "Français"),
            ("en", "English", "English"),
            ("am", "Amharic", "አማርኛ"),
            ("om", "Afaan Oromoo", "Afaan Oromoo"),
        ]
        language_rows: dict[str, Language] = {}
        for iso_code, english_name, native_name in languages:
            result = await db.execute(select(Language).where(Language.iso_code == iso_code))
            row = result.scalar_one_or_none()
            if row is None:
                row = Language(
                    iso_code=iso_code,
                    english_name=english_name,
                    native_name=native_name,
                    created_at=now,
                )
                db.add(row)
                await db.flush()
            language_rows[iso_code] = row

        plan_specs = {
            "free": {"tier": "free", "price": 0, "features": {"ai_explain": 10, "ai_correct": 10, "pronunciation_feedback": 3}},
            "pro": {"tier": "pro", "price": 9.99, "features": {"ai_explain": 200, "ai_correct": 200, "pronunciation_feedback": 50}},
            "pro_plus": {"tier": "pro_plus", "price": 19.99, "features": {"ai_explain": None, "ai_correct": None, "pronunciation_feedback": 200}},
            "school": {"tier": "school", "price": 49.99, "features": {"ai_explain": None, "ai_correct": None, "pronunciation_feedback": None}},
        }
        for code, spec in plan_specs.items():
            result = await db.execute(select(SubscriptionPlan).where(SubscriptionPlan.code == code))
            plan = result.scalar_one_or_none()
            if plan is None:
                plan = SubscriptionPlan(
                    code=code,
                    name=code.replace("_", " ").title(),
                    tier=spec["tier"],
                    price_monthly=spec["price"],
                    created_at=now,
                    updated_at=now,
                )
                db.add(plan)
                await db.flush()
            for feature_key, limit in spec["features"].items():
                exists = await db.execute(
                    select(PlanFeature).where(PlanFeature.plan_id == plan.id, PlanFeature.feature_key == feature_key)
                )
                if exists.scalar_one_or_none() is None:
                    db.add(
                        PlanFeature(
                            plan_id=plan.id,
                            feature_key=feature_key,
                            limit_per_day=limit,
                            created_at=now,
                        )
                    )

        course_result = await db.execute(select(Course).where(Course.code == "fr-a1-foundations"))
        course = course_result.scalar_one_or_none()
        if course is None:
            course = Course(
                target_language_id=language_rows["fr"].id,
                code="fr-a1-foundations",
                level_min="a1",
                level_max="a1",
                is_published=True,
                published_at=now,
                created_at=now,
                updated_at=now,
            )
            db.add(course)
            await db.flush()
            db.add(
                CourseI18n(
                    course_id=course.id,
                    language_id=language_rows["en"].id,
                    title="French A1 Foundations",
                    subtitle="Start speaking simple French",
                    description="A first CEFR A1 course for greetings, identity, and survival phrases.",
                )
            )

        path_result = await db.execute(select(LearningPath).where(LearningPath.course_id == course.id))
        path = path_result.scalar_one_or_none()
        if path is None:
            path = LearningPath(course_id=course.id, path_version=1, is_active=True, created_at=now)
            db.add(path)
            await db.flush()

        unit_result = await db.execute(select(PathUnit).where(PathUnit.learning_path_id == path.id, PathUnit.unit_no == 1))
        unit = unit_result.scalar_one_or_none()
        if unit is None:
            unit = PathUnit(
                learning_path_id=path.id,
                unit_kind="core",
                cefr_level="a1",
                unit_no=1,
                guidebook_payload={"focus": "Greetings and introductions"},
                created_at=now,
            )
            db.add(unit)
            await db.flush()
            db.add(
                PathUnitI18n(
                    unit_id=unit.id,
                    language_id=language_rows["en"].id,
                    title="First French Greetings",
                    description="Say hello, introduce yourself, and recognize polite forms.",
                )
            )

        lesson_result = await db.execute(select(Lesson).where(Lesson.course_id == course.id, Lesson.order_index == 1))
        lesson = lesson_result.scalar_one_or_none()
        if lesson is None:
            lesson = Lesson(
                course_id=course.id,
                level="A1",
                type="vocabulary",
                lesson_kind="dialogue",
                content={
                    "blocks": [
                        {
                            "type": "dialogue",
                            "title": "Bonjour",
                            "hint": "Bonjour works for hello and good morning.",
                            "base_explanation": "Use bonjour in polite daytime greetings.",
                            "answer": "Bonjour",
                            "choices": ["Bonjour", "Merci", "Au revoir"],
                        }
                    ]
                },
                xp_reward=20,
                order_index=1,
                is_published=True,
                published_at=now,
                created_at=now,
                updated_at=now,
            )
            db.add(lesson)
            await db.flush()
            db.add(UnitLesson(unit_id=unit.id, lesson_id=lesson.id, sort_no=1))

        question_specs = [
            (
                1,
                "mcq_single",
                {"stem": "How do you say hello politely in French?", "choices": ["Bonjour", "Merci", "Salut"]},
                {"answer": "Bonjour"},
            ),
            (
                2,
                "translation",
                {"stem": "Translate: Thank you", "target_language": "fr"},
                {"answer": "Merci"},
            ),
        ]
        for sequence_no, kind, prompt, grading in question_specs:
            exists = await db.execute(select(Question).where(Question.lesson_id == lesson.id, Question.sequence_no == sequence_no))
            if exists.scalar_one_or_none() is None:
                db.add(
                    Question(
                        lesson_id=lesson.id,
                        question_kind=kind,
                        sequence_no=sequence_no,
                        prompt_payload=prompt,
                        grading_payload=grading,
                        hint_payload={"hint": "Think of everyday polite phrases."},
                        created_at=now,
                        updated_at=now,
                    )
                )

        await db.commit()
        print("Seeded Fluentian schema sample data.")


if __name__ == "__main__":
    asyncio.run(main())
