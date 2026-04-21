from datetime import UTC, date, datetime, timedelta

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.models.match_pair import MatchPair
from app.models.rtc_session import RealtimeSession
from app.models.session_report import SessionReport
from app.models.user import User
from app.models.user_stats import UserStats
from app.schemas.realtime import SessionEndRequest, SessionReportRequest, SessionSummaryResponse, UserStatsResponse
from app.services.notification_service import create_notification
from app.services.recording_service import persist_session_recordings
from app.services.realtime_service import build_event, publish_user_event, set_presence
from app.tasks.realtime_tasks import aggregate_analytics_task, delete_recording_task, process_recording_task


async def _stats_row(db: AsyncSession, user_id: int, for_date: date) -> UserStats:
    result = await db.execute(
        select(UserStats).where(and_(UserStats.user_id == user_id, UserStats.date == for_date))
    )
    row = result.scalar_one_or_none()
    if row:
        return row

    row = UserStats(user_id=user_id, date=for_date, total_call_duration=0, session_count=0)
    db.add(row)
    await db.flush()
    return row


async def end_session(db: AsyncSession, actor: User, payload: SessionEndRequest) -> SessionSummaryResponse:
    result = await db.execute(select(RealtimeSession).where(RealtimeSession.id == payload.session_id))
    session = result.scalar_one_or_none()
    if not session:
        raise AppException("Session not found", status_code=404, code="session_not_found")

    if actor.id not in {session.user_a_id, session.user_b_id}:
        raise AppException("Forbidden", status_code=403, code="session_forbidden")

    if session.status != "active":
        return SessionSummaryResponse(
            session_id=session.id,
            participants=[session.user_a_id, session.user_b_id],
            session_type=session.session_type,
            start_time=session.started_at,
            end_time=session.ended_at,
            duration=session.duration_seconds,
            status=session.status,
            recording_url=session.recording_url,
            report_flag=session.report_flag,
        )

    now = datetime.now(UTC)
    ended_at = now
    duration = payload.duration
    if duration <= 0:
        duration = int((ended_at - session.started_at).total_seconds())
        if duration < 0:
            duration = 0

    session.status = "ended"
    session.ended_at = ended_at
    session.duration_seconds = duration

    pair_result = await db.execute(
        select(MatchPair).where(
            MatchPair.active.is_(True),
            or_(
                and_(MatchPair.user_a_id == session.user_a_id, MatchPair.user_b_id == session.user_b_id),
                and_(MatchPair.user_a_id == session.user_b_id, MatchPair.user_b_id == session.user_a_id),
            ),
        )
    )
    pair = pair_result.scalar_one_or_none()
    if pair:
        pair.active = False

    today = date.today()
    stats_a = await _stats_row(db, session.user_a_id, today)
    stats_b = await _stats_row(db, session.user_b_id, today)

    stats_a.total_call_duration += duration
    stats_a.session_count += 1
    stats_b.total_call_duration += duration
    stats_b.session_count += 1

    users_result = await db.execute(select(User).where(User.id.in_([session.user_a_id, session.user_b_id])))
    users = users_result.scalars().all()
    for user in users:
        if user.avg_session_duration_seconds <= 0:
            user.avg_session_duration_seconds = duration
        else:
            user.avg_session_duration_seconds = int((user.avg_session_duration_seconds * 0.8) + (duration * 0.2))

    await set_presence(session.user_a_id, "online")
    await set_presence(session.user_b_id, "online")
    await persist_session_recordings(db, session)

    await db.commit()

    await publish_user_event(
        session.user_a_id,
        build_event("SESSION_ENDED", {"session_id": session.id, "duration": duration, "ended_by": payload.ended_by}),
    )
    await publish_user_event(
        session.user_b_id,
        build_event("SESSION_ENDED", {"session_id": session.id, "duration": duration, "ended_by": payload.ended_by}),
    )
    await create_notification(
        db,
        user_id=session.user_a_id,
        event_type="session_ended",
        title="Session ended",
        body=f"Your {session.session_type} session has ended.",
        metadata={"session_id": session.id, "duration": duration},
        commit=False,
    )
    await create_notification(
        db,
        user_id=session.user_b_id,
        event_type="session_ended",
        title="Session ended",
        body=f"Your {session.session_type} session has ended.",
        metadata={"session_id": session.id, "duration": duration},
        commit=False,
    )
    await db.commit()

    try:
        aggregate_analytics_task.delay(session.id)
        if session.recording_url:
            process_recording_task.delay(session.id)
            retention = get_settings().recording_retention_hours
            delete_recording_task.apply_async(args=[session.id], eta=datetime.utcnow() + timedelta(hours=retention))
    except Exception:
        # Worker infrastructure can be optional in local dev; API completion should still succeed.
        pass

    return SessionSummaryResponse(
        session_id=session.id,
        participants=[session.user_a_id, session.user_b_id],
        session_type=session.session_type,
        start_time=session.started_at,
        end_time=session.ended_at,
        duration=session.duration_seconds,
        status=session.status,
        recording_url=session.recording_url,
        report_flag=session.report_flag,
    )


async def report_user(db: AsyncSession, actor: User, payload: SessionReportRequest) -> dict[str, str]:
    result = await db.execute(select(RealtimeSession).where(RealtimeSession.id == payload.session_id))
    session = result.scalar_one_or_none()
    if not session:
        raise AppException("Session not found", status_code=404, code="session_not_found")

    if actor.id not in {session.user_a_id, session.user_b_id}:
        raise AppException("Forbidden", status_code=403, code="session_forbidden")

    if payload.reported_user_id not in {session.user_a_id, session.user_b_id}:
        raise AppException("Reported user is not in this session", status_code=400, code="invalid_report_target")
    if payload.reported_user_id == actor.id:
        raise AppException("You cannot report yourself", status_code=400, code="invalid_report_target")

    report = SessionReport(
        session_id=session.id,
        reporter_user_id=actor.id,
        reported_user_id=payload.reported_user_id,
        reason=payload.reason,
        created_at=datetime.now(UTC),
        status="open",
    )
    db.add(report)

    reported_user_result = await db.execute(select(User).where(User.id == payload.reported_user_id))
    reported_user = reported_user_result.scalar_one_or_none()
    if reported_user:
        reported_user.report_count += 1
        await create_notification(
            db,
            user_id=reported_user.id,
            event_type="safety_report",
            title="Account safety notice",
            body="A report was submitted for a recent session. Our safety team may review this.",
            metadata={"session_id": session.id, "reason": payload.reason},
            commit=False,
        )

    session.report_flag = True
    await db.commit()
    return {"status": "ok"}


async def get_user_stats(db: AsyncSession, user: User) -> UserStatsResponse:
    today = date.today()
    yesterday = today - timedelta(days=1)
    week_start = today - timedelta(days=6)

    rows_result = await db.execute(select(UserStats).where(UserStats.user_id == user.id, UserStats.date >= week_start))
    rows = rows_result.scalars().all()

    today_duration = 0
    yesterday_duration = 0
    weekly_duration = 0
    weekly_sessions = 0
    for row in rows:
        weekly_duration += row.total_call_duration
        weekly_sessions += row.session_count
        if row.date == today:
            today_duration += row.total_call_duration
        if row.date == yesterday:
            yesterday_duration += row.total_call_duration

    total_sessions_result = await db.execute(
        select(func.count(RealtimeSession.id)).where(
            RealtimeSession.status == "ended",
            or_(RealtimeSession.user_a_id == user.id, RealtimeSession.user_b_id == user.id),
        )
    )
    total_sessions = int(total_sessions_result.scalar() or 0)

    avg_session_duration = (weekly_duration / weekly_sessions) if weekly_sessions > 0 else 0.0

    return UserStatsResponse(
        today=today_duration,
        yesterday=yesterday_duration,
        weekly=weekly_duration,
        total_sessions=total_sessions,
        average_session_duration=avg_session_duration,
        last_active_time=datetime.now(UTC),
    )
