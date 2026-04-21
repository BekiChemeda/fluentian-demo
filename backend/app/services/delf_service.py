import json
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.delf import DelfMockResult, DelfMockTest
from app.models.user import User
from app.schemas.delf import DelfQuestion, DelfSubmitRequest


_DEFAULT_TESTS: list[dict] = [
    {
        "title": "DELF A1 Mini Mock",
        "level": "A1",
        "description": "Short comprehension and grammar mock test for DELF A1.",
        "passing_score": 70,
        "questions": [
            {
                "id": "a1_q1",
                "prompt": "Choose the correct greeting: ___, Madame.",
                "choices": ["Bonjour", "Merci", "Au revoir"],
                "answer": "Bonjour",
            },
            {
                "id": "a1_q2",
                "prompt": "Translate 'I am a student' into French.",
                "choices": ["Je suis etudiant", "Tu es etudiant", "Il est etudiant"],
                "answer": "Je suis etudiant",
            },
            {
                "id": "a1_q3",
                "prompt": "Choose the correct article: ___ livre est bleu.",
                "choices": ["Le", "La", "Les"],
                "answer": "Le",
            },
        ],
    },
    {
        "title": "DELF A2 Mini Mock",
        "level": "A2",
        "description": "Short scenario-based mock test for DELF A2.",
        "passing_score": 70,
        "questions": [
            {
                "id": "a2_q1",
                "prompt": "Complete: Je ___ au marche hier.",
                "choices": ["vais", "suis alle", "aller"],
                "answer": "suis alle",
            },
            {
                "id": "a2_q2",
                "prompt": "Best response to an invitation: 'Tu viens ce soir ?'",
                "choices": ["Oui, avec plaisir", "Je suis une pomme", "Merci beaucoup"],
                "answer": "Oui, avec plaisir",
            },
            {
                "id": "a2_q3",
                "prompt": "Choose the formal request:",
                "choices": ["Donne-moi ca", "Pouvez-vous m'aider ?", "Tu viens"],
                "answer": "Pouvez-vous m'aider ?",
            },
        ],
    },
]


async def ensure_default_tests(db: AsyncSession) -> None:
    existing = await db.execute(select(DelfMockTest.id).limit(1))
    if existing.scalar_one_or_none() is not None:
        return

    for item in _DEFAULT_TESTS:
        db.add(
            DelfMockTest(
                title=item["title"],
                level=item["level"],
                description=item["description"],
                questions_json=json.dumps(item["questions"], separators=(",", ":")),
                passing_score=item["passing_score"],
            )
        )
    await db.commit()


def parse_questions(raw: str) -> list[DelfQuestion]:
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise AppException("Invalid DELF test format", status_code=500, code="delf_invalid_format") from exc

    if not isinstance(parsed, list):
        raise AppException("Invalid DELF test format", status_code=500, code="delf_invalid_format")

    questions: list[DelfQuestion] = []
    for item in parsed:
        if not isinstance(item, dict):
            continue

        choices = item.get("choices", [])
        if not isinstance(choices, list):
            choices = []
        normalized_choices = [str(choice) for choice in choices]

        answer = item.get("answer")
        if not isinstance(answer, str) or not answer.strip():
            correct_index = item.get("correct_index")
            if isinstance(correct_index, int) and 0 <= correct_index < len(normalized_choices):
                answer = normalized_choices[correct_index]
            else:
                answer = ""

        normalized = {
            "id": str(item.get("id", "")),
            "prompt": str(item.get("prompt", "")),
            "choices": normalized_choices,
            "answer": answer,
        }
        questions.append(DelfQuestion.model_validate(normalized))
    return questions


async def list_tests(db: AsyncSession) -> list[DelfMockTest]:
    await ensure_default_tests(db)
    result = await db.execute(select(DelfMockTest).order_by(DelfMockTest.level.asc(), DelfMockTest.id.asc()))
    return result.scalars().all()


async def get_test(db: AsyncSession, test_id: int) -> DelfMockTest:
    await ensure_default_tests(db)
    result = await db.execute(select(DelfMockTest).where(DelfMockTest.id == test_id))
    test = result.scalar_one_or_none()
    if test is None:
        raise AppException("DELF test not found", status_code=404, code="delf_test_not_found")
    return test


async def submit_test(db: AsyncSession, user: User, test_id: int, payload: DelfSubmitRequest) -> DelfMockResult:
    test = await get_test(db, test_id)
    questions = parse_questions(test.questions_json)
    answer_map = {item.question_id: item.answer.strip() for item in payload.answers}

    correct = 0
    for question in questions:
        submitted = answer_map.get(question.id, "")
        if submitted.strip().lower() == question.answer.strip().lower():
            correct += 1

    total = max(1, len(questions))
    score = round((correct / total) * 100)

    result = DelfMockResult(
        user_id=user.id,
        test_id=test.id,
        score=score,
        correct_count=correct,
        total_questions=len(questions),
        answers_json=json.dumps(answer_map, separators=(",", ":")),
        submitted_at=datetime.now(UTC),
    )
    db.add(result)
    await db.commit()
    await db.refresh(result)
    return result


async def list_results(db: AsyncSession, user: User) -> list[tuple[DelfMockResult, DelfMockTest]]:
    result = await db.execute(
        select(DelfMockResult, DelfMockTest)
        .join(DelfMockTest, DelfMockTest.id == DelfMockResult.test_id)
        .where(DelfMockResult.user_id == user.id)
        .order_by(DelfMockResult.submitted_at.desc())
    )
    return list(result.all())
