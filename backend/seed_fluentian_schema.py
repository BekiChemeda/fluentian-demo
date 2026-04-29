import asyncio
from datetime import UTC, datetime, time, timedelta

from sqlalchemy import select

from app.core.security import hash_password
from app.db.base import Base
from app.db.session import AsyncSessionLocal, engine
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
from app.models.opportunity import Opportunity, OpportunityCategory
from app.models.subscription import PlanFeature, SubscriptionPlan
from app.models.tutor import TutorAvailability, TutorProfile
from app.models.user import User


SEED_PASSWORD = "FluentianSeed123!"


async def main() -> None:
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with AsyncSessionLocal() as db:
        now = datetime.now(UTC)

        languages = await _seed_languages(db, now)
        admin = await _seed_user(
            db,
            email="admin@fluentian.local",
            role="admin",
            native_language="English",
            now=now,
        )
        await _seed_subscription_plans(db, now)
        course, path = await _seed_course(db, languages, admin, now)
        await _seed_units_lessons_questions(db, languages, course, path, admin, now)
        await _seed_tutors(db, now)
        await _seed_opportunities(db, admin, now)

        await db.commit()
        print("Seeded expanded Fluentian data.")
        print(f"Seed login password for demo users: {SEED_PASSWORD}")


async def _seed_languages(db, now: datetime) -> dict[str, Language]:
    specs = [
        ("fr", "French", "Francais"),
        ("en", "English", "English"),
        ("am", "Amharic", "Amarigna"),
        ("om", "Afaan Oromoo", "Afaan Oromoo"),
        ("ti", "Tigrinya", "Tigrinya"),
        ("so", "Somali", "Soomaali"),
        ("ar", "Arabic", "Al-Arabiyah"),
    ]
    rows: dict[str, Language] = {}
    for iso_code, english_name, native_name in specs:
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
        else:
            row.english_name = english_name
            row.native_name = native_name
            row.is_active = True
        rows[iso_code] = row
    return rows


async def _seed_subscription_plans(db, now: datetime) -> None:
    plan_specs = {
        "free": {
            "tier": "free",
            "price": 0,
            "features": {
                "ai_explain": 10,
                "ai_correct": 10,
                "pronunciation_feedback": 3,
                "tutor_bookings": 0,
                "opportunity_guidance": 3,
                "community_calls": 2,
            },
        },
        "pro": {
            "tier": "pro",
            "price": 9.99,
            "features": {
                "ai_explain": 200,
                "ai_correct": 200,
                "pronunciation_feedback": 50,
                "tutor_bookings": 4,
                "opportunity_guidance": 30,
                "community_calls": 20,
            },
        },
        "pro_plus": {
            "tier": "pro_plus",
            "price": 19.99,
            "features": {
                "ai_explain": None,
                "ai_correct": None,
                "pronunciation_feedback": 200,
                "tutor_bookings": 12,
                "opportunity_guidance": None,
                "community_calls": None,
            },
        },
        "school": {
            "tier": "school",
            "price": 49.99,
            "features": {
                "ai_explain": None,
                "ai_correct": None,
                "pronunciation_feedback": None,
                "tutor_bookings": None,
                "opportunity_guidance": None,
                "community_calls": None,
                "classroom_admin": None,
            },
        },
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
        else:
            plan.name = code.replace("_", " ").title()
            plan.tier = spec["tier"]
            plan.price_monthly = spec["price"]
            plan.is_active = True
            plan.updated_at = now

        for feature_key, limit in spec["features"].items():
            exists = await db.execute(
                select(PlanFeature).where(
                    PlanFeature.plan_id == plan.id,
                    PlanFeature.feature_key == feature_key,
                )
            )
            feature = exists.scalar_one_or_none()
            if feature is None:
                db.add(
                    PlanFeature(
                        plan_id=plan.id,
                        feature_key=feature_key,
                        limit_per_day=limit,
                        created_at=now,
                    )
                )
            else:
                feature.limit_per_day = limit


async def _seed_course(db, languages: dict[str, Language], admin: User, now: datetime) -> tuple[Course, LearningPath]:
    result = await db.execute(select(Course).where(Course.code == "fr-a1-foundations"))
    course = result.scalar_one_or_none()
    if course is None:
        course = Course(
            target_language_id=languages["fr"].id,
            code="fr-a1-foundations",
            level_min="a1",
            level_max="a2",
            is_published=True,
            created_by=admin.id,
            updated_by=admin.id,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        db.add(course)
        await db.flush()
    else:
        course.level_min = "a1"
        course.level_max = "a2"
        course.is_published = True
        course.updated_by = admin.id
        course.updated_at = now
        course.published_at = course.published_at or now

    i18n_specs = [
        (
            "en",
            "French A1 Foundations",
            "Start speaking simple French",
            "A practical beginner course for greetings, identity, daily routines, travel, and polite conversation.",
        ),
        (
            "am",
            "French A1 Foundations",
            "Learn French with Amharic support",
            "Beginner French lessons with local-language style explanations.",
        ),
        (
            "om",
            "French A1 Foundations",
            "Learn French with Afaan Oromoo support",
            "Core French phrases and grammar explained for local-language learners.",
        ),
    ]
    for iso_code, title, subtitle, description in i18n_specs:
        result = await db.execute(
            select(CourseI18n).where(
                CourseI18n.course_id == course.id,
                CourseI18n.language_id == languages[iso_code].id,
            )
        )
        row = result.scalar_one_or_none()
        if row is None:
            db.add(
                CourseI18n(
                    course_id=course.id,
                    language_id=languages[iso_code].id,
                    title=title,
                    subtitle=subtitle,
                    description=description,
                )
            )
        else:
            row.title = title
            row.subtitle = subtitle
            row.description = description

    result = await db.execute(
        select(LearningPath).where(
            LearningPath.course_id == course.id,
            LearningPath.path_version == 1,
        )
    )
    path = result.scalar_one_or_none()
    if path is None:
        path = LearningPath(course_id=course.id, path_version=1, is_active=True, created_at=now)
        db.add(path)
        await db.flush()
    else:
        path.is_active = True
    return course, path


async def _seed_units_lessons_questions(
    db,
    languages: dict[str, Language],
    course: Course,
    path: LearningPath,
    admin: User,
    now: datetime,
) -> None:
    units = [
        {
            "unit_no": 1,
            "title": "Greetings and Identity",
            "description": "Say hello, introduce yourself, and use polite forms.",
            "kind": "core",
            "level": "a1",
            "focus": "greetings, names, politeness",
            "lessons": [
                _lesson("Bonjour and Salut", "dialogue", 20, "Bonjour", "Bonjour works for polite daytime greetings.", ["Bonjour", "Merci", "Au revoir"], "Bonjour"),
                _lesson("Saying Your Name", "dialogue", 20, "Je m'appelle", "Use je m'appelle before your name.", ["Je m'appelle Hana", "Je suis cafe", "Au revoir"], "Je m'appelle Hana"),
                _lesson("Polite Thanks", "vocabulary", 15, "Merci", "Merci is the most common way to say thank you.", ["Merci", "Pardon", "Bonsoir"], "Merci"),
                _lesson("Goodbye Choices", "vocabulary", 15, "Au revoir", "Use au revoir in polite goodbyes.", ["Au revoir", "Bonjour", "Je vais"], "Au revoir"),
            ],
        },
        {
            "unit_no": 2,
            "title": "People and Places",
            "description": "Talk about where you are from and where you live.",
            "kind": "core",
            "level": "a1",
            "focus": "countries, cities, origin",
            "lessons": [
                _lesson("Where Are You From?", "dialogue", 20, "Je viens d'Ethiopie", "Je viens de means I come from.", ["Je viens d'Ethiopie", "Je mange du pain", "Merci beaucoup"], "Je viens d'Ethiopie"),
                _lesson("I Live In", "translation", 20, "J'habite a Addis-Abeba", "Use j'habite a before a city.", ["J'habite a Addis-Abeba", "Je suis merci", "Il va bonjour"], "J'habite a Addis-Abeba"),
                _lesson("Nationalities", "vocabulary", 15, "Je suis ethiopien", "Nationalities change with gender in French.", ["Je suis ethiopien", "Je suis pain", "Je suis au revoir"], "Je suis ethiopien"),
            ],
        },
        {
            "unit_no": 3,
            "title": "Daily Life",
            "description": "Use simple verbs for routines, food, and time.",
            "kind": "practice",
            "level": "a1",
            "focus": "routine, food, time",
            "lessons": [
                _lesson("Morning Routine", "vocabulary", 20, "Je me leve", "Je me leve means I get up.", ["Je me leve", "Je suis ville", "Au revoir"], "Je me leve"),
                _lesson("Ordering Coffee", "dialogue", 20, "Un cafe, s'il vous plait", "S'il vous plait makes requests polite.", ["Un cafe, s'il vous plait", "Je viens lundi", "Comment merci"], "Un cafe, s'il vous plait"),
                _lesson("Telling Time", "listening", 15, "Il est huit heures", "Il est is used for telling time.", ["Il est huit heures", "Je suis huit", "Bonjour heures"], "Il est huit heures"),
            ],
        },
        {
            "unit_no": 4,
            "title": "Travel Basics",
            "description": "Ask for help, directions, and simple prices.",
            "kind": "checkpoint",
            "level": "a1",
            "focus": "travel, help, prices",
            "lessons": [
                _lesson("Asking Directions", "dialogue", 20, "Ou est la gare ?", "Ou est means where is.", ["Ou est la gare ?", "Je suis gare", "Merci la gare"], "Ou est la gare ?"),
                _lesson("How Much Is It?", "translation", 20, "C'est combien ?", "C'est combien asks for a price.", ["C'est combien ?", "Je combien", "Ou merci"], "C'est combien ?"),
                _lesson("A1 Checkpoint", "exam_drill", 30, "Je voudrais un billet", "Je voudrais is a polite way to say I would like.", ["Je voudrais un billet", "Je suis un billet", "Bonjour voudrais"], "Je voudrais un billet"),
            ],
        },
    ]

    for unit_spec in units:
        unit = await _upsert_unit(db, path, languages, unit_spec, now)
        for index, lesson_spec in enumerate(unit_spec["lessons"], start=1):
            sort_no = index
            global_order = (unit_spec["unit_no"] - 1) * 10 + index
            lesson = await _upsert_lesson(db, course, admin, lesson_spec, global_order, now)
            await _upsert_unit_lesson(db, unit, lesson, sort_no)
            await _upsert_questions(db, lesson, lesson_spec, now)


def _lesson(title: str, lesson_kind: str, xp_reward: int, stem: str, explanation: str, choices: list[str], answer: str) -> dict:
    return {
        "title": title,
        "lesson_kind": lesson_kind,
        "xp_reward": xp_reward,
        "stem": stem,
        "explanation": explanation,
        "choices": choices,
        "answer": answer,
    }


async def _upsert_unit(db, path: LearningPath, languages: dict[str, Language], spec: dict, now: datetime) -> PathUnit:
    result = await db.execute(
        select(PathUnit).where(
            PathUnit.learning_path_id == path.id,
            PathUnit.unit_no == spec["unit_no"],
        )
    )
    unit = result.scalar_one_or_none()
    if unit is None:
        unit = PathUnit(
            learning_path_id=path.id,
            unit_kind=spec["kind"],
            cefr_level=spec["level"],
            unit_no=spec["unit_no"],
            guidebook_payload={"focus": spec["focus"]},
            created_at=now,
        )
        db.add(unit)
        await db.flush()
    else:
        unit.unit_kind = spec["kind"]
        unit.cefr_level = spec["level"]
        unit.guidebook_payload = {"focus": spec["focus"]}

    result = await db.execute(
        select(PathUnitI18n).where(
            PathUnitI18n.unit_id == unit.id,
            PathUnitI18n.language_id == languages["en"].id,
        )
    )
    i18n = result.scalar_one_or_none()
    if i18n is None:
        db.add(
            PathUnitI18n(
                unit_id=unit.id,
                language_id=languages["en"].id,
                title=spec["title"],
                description=spec["description"],
            )
        )
    else:
        i18n.title = spec["title"]
        i18n.description = spec["description"]
    return unit


async def _upsert_lesson(db, course: Course, admin: User, spec: dict, order_index: int, now: datetime) -> Lesson:
    result = await db.execute(select(Lesson).where(Lesson.course_id == course.id, Lesson.order_index == order_index))
    lesson = result.scalar_one_or_none()
    content = {
        "blocks": [
            {
                "type": "dialogue" if spec["lesson_kind"] == "dialogue" else "translation_mcq",
                "title": spec["title"],
                "hint": spec["explanation"],
                "base_explanation": spec["explanation"],
                "explanation_placement": "middle",
                "has_question": True,
                "answer": spec["answer"],
                "choices": spec["choices"],
                "tokens": spec["answer"].replace("?", "").split(),
                "dialogue": [
                    {"speaker": "Tutor", "text": spec["stem"], "mine": False},
                    {"speaker": "You", "text": "...", "mine": True},
                ],
            },
            {
                "type": "sentence",
                "title": f"Pattern: {spec['answer']}",
                "hint": "Read the phrase and notice the sentence order.",
                "base_explanation": spec["explanation"],
                "explanation_placement": "top",
                "has_question": False,
                "answer": spec["answer"],
                "choices": [],
                "tokens": [],
                "dialogue": [],
            },
        ]
    }
    if lesson is None:
        lesson = Lesson(
            course_id=course.id,
            level="A1",
            type=spec["lesson_kind"],
            lesson_kind=spec["lesson_kind"],
            content=content,
            xp_reward=spec["xp_reward"],
            order_index=order_index,
            is_published=True,
            created_by=admin.id,
            updated_by=admin.id,
            published_at=now,
            created_at=now,
            updated_at=now,
        )
        db.add(lesson)
        await db.flush()
    else:
        lesson.level = "A1"
        lesson.type = spec["lesson_kind"]
        lesson.lesson_kind = spec["lesson_kind"]
        lesson.content = content
        lesson.xp_reward = spec["xp_reward"]
        lesson.is_published = True
        lesson.updated_by = admin.id
        lesson.updated_at = now
        lesson.published_at = lesson.published_at or now
    return lesson


async def _upsert_unit_lesson(db, unit: PathUnit, lesson: Lesson, sort_no: int) -> None:
    result = await db.execute(
        select(UnitLesson).where(
            UnitLesson.unit_id == unit.id,
            UnitLesson.lesson_id == lesson.id,
        )
    )
    row = result.scalar_one_or_none()
    if row is None:
        db.add(UnitLesson(unit_id=unit.id, lesson_id=lesson.id, sort_no=sort_no))
    else:
        row.sort_no = sort_no


async def _upsert_questions(db, lesson: Lesson, spec: dict, now: datetime) -> None:
    question_specs = [
        (
            1,
            "mcq_single",
            {"stem": spec["stem"], "choices": spec["choices"]},
            {"answer": spec["answer"]},
            {"hint": spec["explanation"]},
        ),
        (
            2,
            "translation",
            {"stem": f"Choose the best French phrase: {spec['title']}", "target_language": "fr"},
            {"answer": spec["answer"]},
            {"hint": "Use the phrase practiced in this lesson."},
        ),
        (
            3,
            "reorder",
            {"stem": "Put the words in order.", "tokens": spec["answer"].replace("?", "").split()},
            {"answer": spec["answer"].replace("?", "").strip()},
            {"hint": "French word order often starts with the subject or polite phrase."},
        ),
    ]
    for sequence_no, kind, prompt, grading, hint in question_specs:
        result = await db.execute(
            select(Question).where(
                Question.lesson_id == lesson.id,
                Question.sequence_no == sequence_no,
            )
        )
        question = result.scalar_one_or_none()
        if question is None:
            db.add(
                Question(
                    lesson_id=lesson.id,
                    question_kind=kind,
                    sequence_no=sequence_no,
                    difficulty=0.45 if sequence_no == 1 else 0.55,
                    prompt_payload=prompt,
                    grading_payload=grading,
                    hint_payload=hint,
                    created_at=now,
                    updated_at=now,
                )
            )
        else:
            question.question_kind = kind
            question.prompt_payload = prompt
            question.grading_payload = grading
            question.hint_payload = hint
            question.updated_at = now


async def _seed_tutors(db, now: datetime) -> None:
    tutor_specs = [
        {
            "email": "camille.tutor@fluentian.local",
            "headline": "A1 conversation coach",
            "bio": "Camille helps beginners speak slowly and confidently with everyday French.",
            "languages": "French, English",
            "rate": 18,
            "timezone": "Africa/Addis_Ababa",
            "availability": [(0, time(9, 0), time(12, 0)), (2, time(14, 0), time(17, 0)), (5, time(10, 0), time(13, 0))],
        },
        {
            "email": "samira.tutor@fluentian.local",
            "headline": "French grammar and exam tutor",
            "bio": "Samira specializes in clear grammar explanations for A1-A2 learners.",
            "languages": "French, Amharic, English",
            "rate": 22,
            "timezone": "Africa/Addis_Ababa",
            "availability": [(1, time(16, 0), time(19, 0)), (3, time(16, 0), time(19, 0)), (6, time(9, 0), time(11, 30))],
        },
        {
            "email": "yassin.tutor@fluentian.local",
            "headline": "Pronunciation and travel French tutor",
            "bio": "Yassin focuses on pronunciation, travel phrases, and roleplay practice.",
            "languages": "French, Afaan Oromoo, English",
            "rate": 20,
            "timezone": "Africa/Addis_Ababa",
            "availability": [(0, time(18, 0), time(20, 0)), (4, time(15, 0), time(18, 0)), (5, time(14, 0), time(17, 0))],
        },
    ]

    for spec in tutor_specs:
        user = await _seed_user(
            db,
            email=spec["email"],
            role="tutor",
            native_language="French",
            now=now,
        )
        result = await db.execute(select(TutorProfile).where(TutorProfile.user_id == user.id))
        profile = result.scalar_one_or_none()
        if profile is None:
            profile = TutorProfile(
                user_id=user.id,
                headline=spec["headline"],
                bio=spec["bio"],
                languages=spec["languages"],
                hourly_rate=spec["rate"],
                currency="USD",
                timezone=spec["timezone"],
                created_at=now,
                updated_at=now,
            )
            db.add(profile)
        else:
            profile.headline = spec["headline"]
            profile.bio = spec["bio"]
            profile.languages = spec["languages"]
            profile.hourly_rate = spec["rate"]
            profile.timezone = spec["timezone"]
            profile.is_active = True
            profile.updated_at = now

        for weekday, start_time, end_time in spec["availability"]:
            result = await db.execute(
                select(TutorAvailability).where(
                    TutorAvailability.tutor_user_id == user.id,
                    TutorAvailability.weekday == weekday,
                    TutorAvailability.start_time == start_time,
                    TutorAvailability.end_time == end_time,
                )
            )
            availability = result.scalar_one_or_none()
            if availability is None:
                db.add(
                    TutorAvailability(
                        tutor_user_id=user.id,
                        weekday=weekday,
                        start_time=start_time,
                        end_time=end_time,
                        timezone=spec["timezone"],
                        created_at=now,
                        updated_at=now,
                    )
                )
            else:
                availability.is_active = True
                availability.timezone = spec["timezone"]
                availability.updated_at = now


async def _seed_opportunities(db, admin: User, now: datetime) -> None:
    categories = {
        "scholarships": "Scholarships",
        "jobs": "Jobs and Internships",
        "exchange": "Exchange Programs",
        "events": "French Events",
    }
    category_rows: dict[str, OpportunityCategory] = {}
    for slug, title in categories.items():
        result = await db.execute(select(OpportunityCategory).where(OpportunityCategory.slug == slug))
        category = result.scalar_one_or_none()
        if category is None:
            category = OpportunityCategory(
                slug=slug,
                title=title,
                description=f"{title} for French learners.",
                created_at=now,
                updated_at=now,
            )
            db.add(category)
            await db.flush()
        else:
            category.title = title
            category.description = f"{title} for French learners."
            category.is_active = True
            category.updated_at = now
        category_rows[slug] = category

    opportunities = [
        {
            "category": "scholarships",
            "title": "Campus France Beginner Pathway",
            "provider": "Campus France",
            "type": "scholarship",
            "country": "FR",
            "deadline_days": 75,
            "description": "A preparation pathway for students planning future French-taught study.",
            "eligibility": "Open to motivated A1-A2 learners preparing study documents.",
            "language": "A1 recommended now; A2-B1 useful before application.",
        },
        {
            "category": "exchange",
            "title": "Francophone Youth Exchange",
            "provider": "Francophone Community Network",
            "type": "exchange",
            "country": "FR",
            "deadline_days": 45,
            "description": "Short cultural exchange with guided beginner conversation activities.",
            "eligibility": "Learners aged 18+ with basic French greetings and self-introduction.",
            "language": "A1 speaking confidence recommended.",
        },
        {
            "category": "jobs",
            "title": "Bilingual Customer Support Internship",
            "provider": "Addis Global Services",
            "type": "internship",
            "country": "ET",
            "deadline_days": 30,
            "description": "Entry internship for learners practicing French service phrases.",
            "eligibility": "Basic computer skills and active French learning plan.",
            "language": "A2 target; A1 accepted with strong English.",
        },
        {
            "category": "events",
            "title": "Alliance Francaise Conversation Night",
            "provider": "Alliance Francaise",
            "type": "event",
            "country": "ET",
            "deadline_days": 14,
            "description": "Weekly beginner-friendly conversation circle with local learners.",
            "eligibility": "Open to all learners.",
            "language": "A0-A2 welcome.",
        },
        {
            "category": "scholarships",
            "title": "French for Tourism Microgrant",
            "provider": "Tourism Skills Fund",
            "type": "grant",
            "country": "ET",
            "deadline_days": 60,
            "description": "Small learning grant for hospitality workers studying French.",
            "eligibility": "Applicants should work or study in tourism, hospitality, or travel.",
            "language": "A1 course completion preferred.",
        },
        {
            "category": "jobs",
            "title": "Remote French Content Assistant",
            "provider": "Lingua Media Studio",
            "type": "part_time",
            "country": None,
            "deadline_days": 90,
            "description": "Part-time role checking beginner French phrase content and translations.",
            "eligibility": "Strong English plus beginner French study record.",
            "language": "A2 recommended.",
        },
    ]

    for spec in opportunities:
        result = await db.execute(select(Opportunity).where(Opportunity.title == spec["title"]))
        opportunity = result.scalar_one_or_none()
        deadline = now + timedelta(days=spec["deadline_days"])
        data = {
            "category_id": category_rows[spec["category"]].id,
            "provider_name": spec["provider"],
            "opportunity_type": spec["type"],
            "country_code": spec["country"],
            "url": "https://example.com/fluentian-opportunity",
            "description": spec["description"],
            "eligibility": spec["eligibility"],
            "language_requirements": spec["language"],
            "deadline_at": deadline,
            "is_published": True,
            "opportunity_metadata": {"seeded": True, "level": "A1-A2"},
            "created_by": admin.id,
            "updated_by": admin.id,
            "published_at": now,
            "updated_at": now,
        }
        if opportunity is None:
            db.add(
                Opportunity(
                    title=spec["title"],
                    created_at=now,
                    **data,
                )
            )
        else:
            for key, value in data.items():
                setattr(opportunity, key, value)
            opportunity.archived_at = None


async def _seed_user(db, email: str, role: str, native_language: str, now: datetime) -> User:
    result = await db.execute(select(User).where(User.email == email))
    user = result.scalar_one_or_none()
    if user is None:
        user = User(
            email=email,
            password_hash=hash_password(SEED_PASSWORD),
            role=role,
            native_language=native_language,
            target_language="French",
            xp=120 if role == "student" else 0,
            streak=3 if role == "student" else 0,
            daily_xp_goal=30,
            cefr_level="A1",
            learning_intent="casual",
            preferred_mode="text",
        )
        db.add(user)
        await db.flush()
    else:
        user.role = role
        user.native_language = native_language
        user.target_language = "French"
        user.cefr_level = user.cefr_level or "A1"
    return user


if __name__ == "__main__":
    asyncio.run(main())
