import json

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.delf import (
    DelfResultsResponse,
    DelfResultItemResponse,
    DelfSubmitRequest,
    DelfSubmitResponse,
    DelfTestDetailResponse,
    DelfTestSummaryResponse,
)
from app.services.delf_service import get_test, list_results, list_tests, submit_test
from app.services.delf_service import parse_questions

router = APIRouter(prefix="/delf", tags=["delf"])


@router.get("/tests", response_model=list[DelfTestSummaryResponse])
async def tests(db: AsyncSession = Depends(get_db), _: User = Depends(get_current_user)) -> list[DelfTestSummaryResponse]:
    rows = await list_tests(db)
    output: list[DelfTestSummaryResponse] = []
    for row in rows:
        try:
            question_count = len(json.loads(row.questions_json))
        except json.JSONDecodeError:
            question_count = 0
        output.append(
            DelfTestSummaryResponse(
                id=row.id,
                title=row.title,
                level=row.level,
                description=row.description,
                question_count=question_count,
                passing_score=row.passing_score,
            )
        )
    return output


@router.get("/tests/{test_id}", response_model=DelfTestDetailResponse)
async def test_detail(
    test_id: int,
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> DelfTestDetailResponse:
    test = await get_test(db, test_id)
    questions = [question.model_dump() for question in parse_questions(test.questions_json)]
    return DelfTestDetailResponse(
        id=test.id,
        title=test.title,
        level=test.level,
        description=test.description,
        questions=questions,
        passing_score=test.passing_score,
    )


@router.post("/tests/{test_id}/submit", response_model=DelfSubmitResponse)
async def submit(
    test_id: int,
    payload: DelfSubmitRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DelfSubmitResponse:
    test = await get_test(db, test_id)
    row = await submit_test(db, user, test_id, payload)
    return DelfSubmitResponse(
        result_id=row.id,
        score=row.score,
        correct_count=row.correct_count,
        total_questions=row.total_questions,
        passed=row.score >= test.passing_score,
    )


@router.get("/results", response_model=DelfResultsResponse)
async def results(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> DelfResultsResponse:
    rows = await list_results(db, user)
    return DelfResultsResponse(
        items=[
            DelfResultItemResponse(
                result_id=result.id,
                test_id=test.id,
                test_title=test.title,
                level=test.level,
                score=result.score,
                correct_count=result.correct_count,
                total_questions=result.total_questions,
                submitted_at=result.submitted_at,
            )
            for result, test in rows
        ]
    )
