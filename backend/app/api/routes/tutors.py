from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.tutor import (
    AvailabilityCreateRequest,
    AvailabilityResponse,
    BookingCancelRequest,
    BookingCreateRequest,
    BookingListResponse,
    BookingResponse,
    TutorListResponse,
    TutorProfileResponse,
)
from app.services.tutor_service import (
    cancel_booking,
    complete_booking,
    create_availability,
    create_booking,
    get_tutor,
    list_availability,
    list_my_bookings,
    list_tutors,
)

router = APIRouter(tags=["tutors"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]


@router.get("/tutors", response_model=TutorListResponse)
async def tutors(
    db: DbDep,
    _: CurrentUserDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> TutorListResponse:
    items, total = await list_tutors(db, page, page_size)
    return TutorListResponse(items=items, page=page, page_size=page_size, total=total)


@router.get("/tutors/{tutor_id}", response_model=TutorProfileResponse)
async def tutor(tutor_id: int, db: DbDep, _: CurrentUserDep) -> TutorProfileResponse:
    return TutorProfileResponse.model_validate(await get_tutor(db, tutor_id))


@router.post("/tutors/me/availability", response_model=AvailabilityResponse)
async def add_availability(payload: AvailabilityCreateRequest, db: DbDep, user: CurrentUserDep) -> AvailabilityResponse:
    return AvailabilityResponse.model_validate(await create_availability(db, user, payload))


@router.get("/tutors/{tutor_id}/availability")
async def availability(tutor_id: int, db: DbDep, _: CurrentUserDep) -> dict:
    rows = await list_availability(db, tutor_id)
    return {"items": [AvailabilityResponse.model_validate(row) for row in rows]}


@router.post("/bookings", response_model=BookingResponse)
async def booking(payload: BookingCreateRequest, db: DbDep, user: CurrentUserDep) -> BookingResponse:
    return BookingResponse.model_validate(await create_booking(db, user, payload))


@router.get("/bookings/me", response_model=BookingListResponse)
async def bookings_me(
    db: DbDep,
    user: CurrentUserDep,
    page: int = Query(default=1, ge=1),
    page_size: int = Query(default=20, ge=1, le=100),
) -> BookingListResponse:
    items, total = await list_my_bookings(db, user, page, page_size)
    return BookingListResponse(items=items, page=page, page_size=page_size, total=total)


@router.patch("/bookings/{booking_id}/cancel", response_model=BookingResponse)
async def cancel(booking_id: UUID, payload: BookingCancelRequest, db: DbDep, user: CurrentUserDep) -> BookingResponse:
    return BookingResponse.model_validate(await cancel_booking(db, user, booking_id, payload.reason))


@router.patch("/bookings/{booking_id}/complete", response_model=BookingResponse)
async def complete(booking_id: UUID, db: DbDep, user: CurrentUserDep) -> BookingResponse:
    return BookingResponse.model_validate(await complete_booking(db, user, booking_id))
