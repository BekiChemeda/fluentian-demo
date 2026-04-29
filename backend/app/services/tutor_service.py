from datetime import UTC, datetime
from uuid import UUID

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.tutor import TutorAvailability, TutorBooking, TutorProfile
from app.models.user import User
from app.schemas.tutor import AvailabilityCreateRequest, BookingCreateRequest


async def list_tutors(db: AsyncSession, page: int, page_size: int) -> tuple[list[TutorProfile], int]:
    stmt = select(TutorProfile).where(TutorProfile.is_active.is_(True))
    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    result = await db.execute(stmt.order_by(TutorProfile.created_at.desc()).offset((page - 1) * page_size).limit(page_size))
    return list(result.scalars().all()), int(total or 0)


async def get_tutor(db: AsyncSession, tutor_user_id: int) -> TutorProfile:
    result = await db.execute(select(TutorProfile).where(TutorProfile.user_id == tutor_user_id, TutorProfile.is_active.is_(True)))
    tutor = result.scalar_one_or_none()
    if tutor is None:
        raise AppException("Tutor not found", status_code=404, code="tutor_not_found")
    return tutor


async def create_availability(db: AsyncSession, user: User, payload: AvailabilityCreateRequest) -> TutorAvailability:
    if user.role not in {"tutor", "admin"}:
        raise AppException("Only tutors can manage availability", status_code=403, code="forbidden")
    now = datetime.now(UTC)
    row = TutorAvailability(
        tutor_user_id=user.id,
        weekday=payload.weekday,
        start_time=payload.start_time,
        end_time=payload.end_time,
        timezone=payload.timezone,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def list_availability(db: AsyncSession, tutor_user_id: int) -> list[TutorAvailability]:
    result = await db.execute(
        select(TutorAvailability)
        .where(TutorAvailability.tutor_user_id == tutor_user_id, TutorAvailability.is_active.is_(True))
        .order_by(TutorAvailability.weekday, TutorAvailability.start_time)
    )
    return list(result.scalars().all())


async def create_booking(db: AsyncSession, user: User, payload: BookingCreateRequest) -> TutorBooking:
    if payload.tutor_user_id == user.id:
        raise AppException("You cannot book yourself", status_code=400, code="invalid_booking")
    await get_tutor(db, payload.tutor_user_id)
    overlap_result = await db.execute(
        select(TutorBooking.id).where(
            TutorBooking.tutor_user_id == payload.tutor_user_id,
            TutorBooking.status.in_(["scheduled", "confirmed"]),
            or_(
                and_(TutorBooking.starts_at < payload.ends_at, TutorBooking.ends_at > payload.starts_at),
            ),
        )
    )
    if overlap_result.scalar_one_or_none() is not None:
        raise AppException("Tutor is already booked for this time", status_code=409, code="tutor_double_booked")
    now = datetime.now(UTC)
    row = TutorBooking(
        student_user_id=user.id,
        tutor_user_id=payload.tutor_user_id,
        starts_at=payload.starts_at,
        ends_at=payload.ends_at,
        status="scheduled",
        topic=payload.topic,
        created_at=now,
        updated_at=now,
    )
    db.add(row)
    await db.commit()
    await db.refresh(row)
    return row


async def list_my_bookings(db: AsyncSession, user: User, page: int, page_size: int) -> tuple[list[TutorBooking], int]:
    stmt = select(TutorBooking).where(
        or_(TutorBooking.student_user_id == user.id, TutorBooking.tutor_user_id == user.id)
    )
    total = await db.scalar(select(func.count()).select_from(stmt.subquery()))
    result = await db.execute(stmt.order_by(TutorBooking.starts_at.desc()).offset((page - 1) * page_size).limit(page_size))
    return list(result.scalars().all()), int(total or 0)


async def cancel_booking(db: AsyncSession, user: User, booking_id: UUID, reason: str) -> TutorBooking:
    booking = await _get_booking_for_actor(db, user, booking_id)
    if booking.status in {"cancelled", "completed"}:
        raise AppException("Booking cannot be cancelled", status_code=400, code="booking_not_cancellable")
    now = datetime.now(UTC)
    booking.status = "cancelled"
    booking.cancellation_reason = reason
    booking.cancelled_by = user.id
    booking.cancelled_at = now
    booking.updated_at = now
    await db.commit()
    await db.refresh(booking)
    return booking


async def complete_booking(db: AsyncSession, user: User, booking_id: UUID) -> TutorBooking:
    booking = await _get_booking_for_actor(db, user, booking_id)
    if user.id != booking.tutor_user_id and user.role != "admin":
        raise AppException("Only the tutor can complete this booking", status_code=403, code="forbidden")
    if booking.status == "cancelled":
        raise AppException("Cancelled booking cannot be completed", status_code=400, code="booking_cancelled")
    now = datetime.now(UTC)
    booking.status = "completed"
    booking.completed_at = now
    booking.updated_at = now
    await db.commit()
    await db.refresh(booking)
    return booking


async def _get_booking_for_actor(db: AsyncSession, user: User, booking_id: UUID) -> TutorBooking:
    booking = await db.get(TutorBooking, booking_id)
    if booking is None:
        raise AppException("Booking not found", status_code=404, code="booking_not_found")
    if user.role != "admin" and user.id not in {booking.student_user_id, booking.tutor_user_id}:
        raise AppException("Booking not found", status_code=404, code="booking_not_found")
    return booking
