from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.opportunity import (
    GuidanceRequest,
    GuidanceResponse,
    OpportunityCreateRequest,
    OpportunityListResponse,
    OpportunityResponse,
    OpportunityUpdateRequest,
)
from app.services.opportunity_service import (
    archive_opportunity,
    create_opportunity,
    get_opportunity,
    list_opportunities,
    request_guidance,
    save_opportunity,
    unsave_opportunity,
    update_opportunity,
)

router = APIRouter(prefix="/opportunities", tags=["opportunities"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.get("", response_model=OpportunityListResponse)
async def opportunities(
    db: DbDep,
    user: CurrentUserDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> OpportunityListResponse:
    items, total = await list_opportunities(db, user, page, page_size)
    return OpportunityListResponse(items=items, page=page, page_size=page_size, total=total)


@router.get("/{opportunity_id}", response_model=OpportunityResponse)
async def opportunity(opportunity_id: UUID, db: DbDep, user: CurrentUserDep) -> OpportunityResponse:
    return OpportunityResponse.model_validate(await get_opportunity(db, user, opportunity_id))


@router.post("", response_model=OpportunityResponse, status_code=status.HTTP_201_CREATED)
async def create(payload: OpportunityCreateRequest, db: DbDep, user: CurrentUserDep) -> OpportunityResponse:
    return OpportunityResponse.model_validate(await create_opportunity(db, user, payload))


@router.patch("/{opportunity_id}", response_model=OpportunityResponse)
async def update(
    opportunity_id: UUID,
    payload: OpportunityUpdateRequest,
    db: DbDep,
    user: CurrentUserDep,
) -> OpportunityResponse:
    return OpportunityResponse.model_validate(await update_opportunity(db, user, opportunity_id, payload))


@router.delete("/{opportunity_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete(opportunity_id: UUID, db: DbDep, user: CurrentUserDep) -> None:
    await archive_opportunity(db, user, opportunity_id)


@router.post("/{opportunity_id}/save")
async def save(opportunity_id: UUID, db: DbDep, user: CurrentUserDep) -> dict[str, str]:
    await save_opportunity(db, user, opportunity_id)
    return {"status": "saved"}


@router.delete("/{opportunity_id}/save")
async def unsave(opportunity_id: UUID, db: DbDep, user: CurrentUserDep) -> dict[str, str]:
    await unsave_opportunity(db, user, opportunity_id)
    return {"status": "removed"}


@router.post("/{opportunity_id}/guidance-request", response_model=GuidanceResponse)
async def guidance(
    opportunity_id: UUID,
    payload: GuidanceRequest,
    db: DbDep,
    user: CurrentUserDep,
) -> GuidanceResponse:
    return GuidanceResponse.model_validate(await request_guidance(db, user, opportunity_id, payload))
