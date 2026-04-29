import json
import uuid
from collections import deque
from datetime import UTC, datetime

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from redis.exceptions import ConnectionError as RedisConnectionError
from redis.exceptions import ResponseError as RedisResponseError

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.core.redis_client import get_redis_client
from app.core.realtime_fallback import (
    clear_user,
    delete_queue_ticket,
    get_event_queue,
    get_presence,
    get_queue_tickets,
    get_ticket,
    set_presence as fallback_set_presence,
    set_queue_ticket,
)
from app.models.match_pair import MatchPair
from app.models.rtc_session import RealtimeSession
from app.models.user import User
from app.schemas.realtime import QueueJoinPayload, RealtimeEnvelope
from app.services.notification_service import create_notification
from app.services.safety_service import is_user_blocked_pair

_CEFR_ORDER = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}
_REDIS_AVAILABLE = True
_RECENT_EVENT_IDS: set[str] = set()
_RECENT_EVENT_ID_ORDER: deque[str] = deque()


def _normalize_language(value: str) -> str:
    v = value.strip().lower()
    if v in {"am", "amharic"}:
        return "AM"
    if v in {"en", "english"}:
        return "EN"
    if v in {"fr", "french"}:
        return "FR"
    return value.strip().upper()


def _event_channel(user_id: int) -> str:
    settings = get_settings()
    return f"{settings.redis_user_events_prefix}:{user_id}"


def _presence_key(user_id: int) -> str:
    settings = get_settings()
    return f"{settings.redis_presence_prefix}:{user_id}"


def _ticket_key(user_id: int) -> str:
    return f"fluentian:match:ticket:{user_id}"


def _session_key(session_id: int) -> str:
    settings = get_settings()
    return f"{settings.redis_session_prefix}:{session_id}"


def _mark_redis_unavailable() -> None:
    global _REDIS_AVAILABLE
    _REDIS_AVAILABLE = False


def _redis_enabled() -> bool:
    return _REDIS_AVAILABLE


def _event_id(payload: dict) -> str:
    event_id = payload.get("_event_id")
    if isinstance(event_id, str) and event_id:
        return event_id
    event_id = uuid.uuid4().hex
    payload["_event_id"] = event_id
    return event_id


def _remember_event_id(event_id: str) -> None:
    if event_id in _RECENT_EVENT_IDS:
        return
    _RECENT_EVENT_IDS.add(event_id)
    _RECENT_EVENT_ID_ORDER.append(event_id)
    while len(_RECENT_EVENT_ID_ORDER) > 4096:
        expired = _RECENT_EVENT_ID_ORDER.popleft()
        _RECENT_EVENT_IDS.discard(expired)


def has_seen_event_id(event_id: str) -> bool:
    return event_id in _RECENT_EVENT_IDS


def remember_event_id(event_id: str) -> None:
    _remember_event_id(event_id)


def build_event(event_type: str, payload: dict) -> RealtimeEnvelope:
    return RealtimeEnvelope(type=event_type, timestamp=datetime.now(UTC), payload=payload)


async def publish_user_event(user_id: int, event: RealtimeEnvelope) -> None:
    event_id = _event_id(event.payload)
    _remember_event_id(event_id)

    local_queue = get_event_queue(user_id)
    local_queue.put_nowait(event.model_dump(mode="json"))

    if _redis_enabled():
        try:
            redis = get_redis_client()
            await redis.publish(_event_channel(user_id), event.model_dump_json())
            return
        except RedisConnectionError:
            _mark_redis_unavailable()


async def _write_presence_mapping(user_id: int, mapping: dict[str, str]) -> None:
    redis = get_redis_client()
    key = _presence_key(user_id)
    try:
        await redis.hset(key, mapping=mapping)
    except RedisResponseError:
        # Redis 3.x does not support multi-field HSET. Write fields individually.
        for field, value in mapping.items():
            await redis.hset(key, field, value)


async def set_presence(user_id: int, status: str, *, session_id: int | None = None) -> None:
    mapping = {
        "status": status,
        "last_seen": datetime.now(UTC).isoformat(),
        "session_id": str(session_id or ""),
    }
    if _redis_enabled():
        try:
            await _write_presence_mapping(user_id, mapping)
            return
        except RedisConnectionError:
            _mark_redis_unavailable()

    fallback_set_presence(user_id, status, session_id=session_id)


async def refresh_heartbeat(user_id: int) -> None:
    if _redis_enabled():
        try:
            await _write_presence_mapping(user_id, {"last_seen": datetime.now(UTC).isoformat()})
            return
        except RedisConnectionError:
            _mark_redis_unavailable()

    fallback_set_presence(user_id, "online")


async def join_queue(user: User, payload: QueueJoinPayload) -> None:
    settings = get_settings()

    target_language = _normalize_language(user.target_language)
    native_language = _normalize_language(user.native_language)

    if target_language != "FR":
        raise AppException("Only French learning queue is available", status_code=400, code="target_not_supported")
    if native_language not in {"AM", "EN"}:
        raise AppException("Base language must be Amharic or English", status_code=400, code="base_not_supported")

    now_ts = datetime.now(UTC).timestamp()
    ticket = {
        "user_id": user.id,
        "native_language": native_language,
        "target_language": target_language,
        "preferred_mode": payload.preferred_mode,
        "learning_intent": payload.learning_intent.lower(),
        "cefr_level": payload.cefr_level,
        "recording_consent": payload.recording_consent,
        "report_count": user.report_count,
        "drop_rate": user.drop_rate,
        "avg_session_duration_seconds": user.avg_session_duration_seconds,
        "enqueued_at": now_ts,
    }

    if _redis_enabled():
        try:
            redis = get_redis_client()
            await redis.set(_ticket_key(user.id), json.dumps(ticket))
            await redis.zadd(settings.redis_queue_key, {str(user.id): now_ts})
        except RedisConnectionError:
            _mark_redis_unavailable()
            set_queue_ticket(user.id, ticket)
    else:
        set_queue_ticket(user.id, ticket)
    await set_presence(user.id, "in_queue")


async def leave_queue(user_id: int) -> None:
    if _redis_enabled():
        try:
            settings = get_settings()
            redis = get_redis_client()
            await redis.zrem(settings.redis_queue_key, str(user_id))
            await redis.delete(_ticket_key(user_id))
        except RedisConnectionError:
            _mark_redis_unavailable()
            delete_queue_ticket(user_id)
    else:
        delete_queue_ticket(user_id)
    await set_presence(user_id, "online")


async def _load_ticket(user_id: int) -> dict | None:
    if _redis_enabled():
        try:
            redis = get_redis_client()
            raw = await redis.get(_ticket_key(user_id))
            if not raw:
                return None
            try:
                parsed = json.loads(raw)
            except json.JSONDecodeError:
                return None
            if not isinstance(parsed, dict):
                return None
            return parsed
        except RedisConnectionError:
            _mark_redis_unavailable()

    return get_ticket(user_id)


def _is_base_compatible(a: dict, b: dict) -> bool:
    settings = get_settings()
    if settings.allow_cross_base_language_matching:
        return True
    return a.get("native_language") == b.get("native_language")


def _strictness(wait_seconds: float) -> str:
    if wait_seconds < 10:
        return "strict"
    if wait_seconds < 30:
        return "relaxed"
    return "broad"


def _score(a: dict, b: dict, now_ts: float) -> float | None:
    if a.get("target_language") != "FR" or b.get("target_language") != "FR":
        return None
    if not _is_base_compatible(a, b):
        return None

    wait_seconds = now_ts - min(float(a.get("enqueued_at", now_ts)), float(b.get("enqueued_at", now_ts)))
    strictness = _strictness(wait_seconds)

    a_level = _CEFR_ORDER.get(str(a.get("cefr_level", "A1")).upper(), 1)
    b_level = _CEFR_ORDER.get(str(b.get("cefr_level", "A1")).upper(), 1)
    level_delta = abs(a_level - b_level)

    same_mode = a.get("preferred_mode") == b.get("preferred_mode")

    if strictness == "strict":
        if level_delta != 0:
            return None
        if a.get("learning_intent") != b.get("learning_intent"):
            return None
    elif strictness == "relaxed":
        if level_delta > 1:
            return None
    else:
        if level_delta > 3:
            return None

    behavior_penalty = (
        float(a.get("report_count", 0))
        + float(b.get("report_count", 0))
        + float(a.get("drop_rate", 0.0)) * 10
        + float(b.get("drop_rate", 0.0)) * 10
    )
    engagement_bonus = (
        float(a.get("avg_session_duration_seconds", 0))
        + float(b.get("avg_session_duration_seconds", 0))
    ) / 120
    # Keep same-mode pairs preferred while still allowing mixed-mode fallback.
    mode_bonus = 5.0 if same_mode else -1.5
    wait_bonus = min(wait_seconds / 5.0, 10.0)

    return mode_bonus + wait_bonus + engagement_bonus - behavior_penalty


async def _active_session_for_user(db: AsyncSession, user_id: int) -> RealtimeSession | None:
    result = await db.execute(
        select(RealtimeSession).where(
            RealtimeSession.status == "active",
            or_(RealtimeSession.user_a_id == user_id, RealtimeSession.user_b_id == user_id),
        )
    )
    return result.scalar_one_or_none()


async def process_matchmaking_once(db: AsyncSession) -> int:
    settings = get_settings()
    if _redis_enabled():
        try:
            redis = get_redis_client()
            queue_user_ids = await redis.zrange(settings.redis_queue_key, 0, 50)
        except RedisConnectionError:
            _mark_redis_unavailable()
            queue_user_ids = [str(ticket["user_id"]) for ticket in get_queue_tickets()]
    else:
        queue_user_ids = [str(ticket["user_id"]) for ticket in get_queue_tickets()]

    tickets: list[dict] = []
    for raw_user_id in queue_user_ids:
        try:
            user_id = int(raw_user_id)
        except ValueError:
            if _redis_enabled():
                try:
                    redis = get_redis_client()
                    await redis.zrem(settings.redis_queue_key, raw_user_id)
                except RedisConnectionError:
                    _mark_redis_unavailable()
            else:
                continue
            continue
        ticket = await _load_ticket(user_id)
        if not ticket:
            if _redis_enabled():
                try:
                    redis = get_redis_client()
                    await redis.zrem(settings.redis_queue_key, raw_user_id)
                except RedisConnectionError:
                    _mark_redis_unavailable()
                    delete_queue_ticket(user_id)
            else:
                delete_queue_ticket(user_id)
            continue
        tickets.append(ticket)

    if len(tickets) < 2:
        return 0

    now_ts = datetime.now(UTC).timestamp()
    matches_created = 0
    used_user_ids: set[int] = set()

    for ticket in tickets:
        user_id = int(ticket["user_id"])
        if user_id in used_user_ids:
            continue
        if await _active_session_for_user(db, user_id):
            await leave_queue(user_id)
            continue

        best_candidate: dict | None = None
        best_score = -10_000.0
        for candidate in tickets:
            candidate_user_id = int(candidate["user_id"])
            if candidate_user_id == user_id or candidate_user_id in used_user_ids:
                continue
            if await _active_session_for_user(db, candidate_user_id):
                await leave_queue(candidate_user_id)
                continue
            if await is_user_blocked_pair(db, user_id, candidate_user_id):
                continue

            score = _score(ticket, candidate, now_ts)
            if score is None:
                continue
            if score > best_score:
                best_score = score
                best_candidate = candidate

        if not best_candidate:
            continue

        peer_id = int(best_candidate["user_id"])
        used_user_ids.add(user_id)
        used_user_ids.add(peer_id)

        mode = "audio" if ticket.get("preferred_mode") == "audio" and best_candidate.get("preferred_mode") == "audio" else "text"
        consent_a = bool(ticket.get("recording_consent", False))
        consent_b = bool(best_candidate.get("recording_consent", False))
        recording_url = None
        if mode == "audio" and consent_a and consent_b:
            recording_url = f"pending://recordings/{user_id}_{peer_id}_{int(now_ts)}"

        session = RealtimeSession(
            user_a_id=user_id,
            user_b_id=peer_id,
            session_type=mode,
            status="active",
            started_at=datetime.now(UTC),
            recording_url=recording_url,
            recording_consent_a=consent_a,
            recording_consent_b=consent_b,
        )
        db.add(session)

        pair = MatchPair(
            user_a_id=user_id,
            user_b_id=peer_id,
            active=True,
            created_at=datetime.now(UTC),
        )
        db.add(pair)
        await db.flush()

        await leave_queue(user_id)
        await leave_queue(peer_id)
        await set_presence(user_id, "in_session", session_id=session.id)
        await set_presence(peer_id, "in_session", session_id=session.id)

        user_result = await db.execute(select(User).where(User.id == user_id))
        peer_result = await db.execute(select(User).where(User.id == peer_id))
        matched_user = user_result.scalar_one_or_none()
        matched_peer = peer_result.scalar_one_or_none()

        session_payload = {
            "session_id": session.id,
            "peer_id": peer_id,
            "peer_email": matched_peer.email if matched_peer else None,
            "peer_xp": matched_peer.xp if matched_peer else 0,
            "peer_streak": matched_peer.streak if matched_peer else 0,
            "peer_language": matched_peer.native_language if matched_peer else None,
            "user_email": matched_user.email if matched_user else None,
            "session_type": mode,
            "recording_enabled": mode == "audio" and consent_a and consent_b,
            "recording_url": recording_url,
        }
        peer_payload = {
            "session_id": session.id,
            "peer_id": user_id,
            "peer_email": matched_user.email if matched_user else None,
            "peer_xp": matched_user.xp if matched_user else 0,
            "peer_streak": matched_user.streak if matched_user else 0,
            "peer_language": matched_user.native_language if matched_user else None,
            "user_email": matched_peer.email if matched_peer else None,
            "session_type": mode,
            "recording_enabled": mode == "audio" and consent_a and consent_b,
            "recording_url": recording_url,
        }

        await publish_user_event(user_id, build_event("MATCH_FOUND", session_payload))
        await publish_user_event(peer_id, build_event("MATCH_FOUND", peer_payload))
        await publish_user_event(user_id, build_event("SESSION_INITIALIZED", session_payload))
        await publish_user_event(peer_id, build_event("SESSION_INITIALIZED", peer_payload))
        await publish_user_event(user_id, build_event("SESSION_STARTED", session_payload))
        await publish_user_event(peer_id, build_event("SESSION_STARTED", peer_payload))
        await publish_user_event(user_id, build_event("SESSION_ACTIVE", session_payload))
        await publish_user_event(peer_id, build_event("SESSION_ACTIVE", peer_payload))
        await create_notification(
            db,
            user_id=user_id,
            event_type="match_found",
            title="Match found",
            body="A compatible learner is ready. Join your session now.",
            metadata={"session_id": session.id, "peer_id": peer_id, "session_type": mode},
            commit=False,
        )
        await create_notification(
            db,
            user_id=peer_id,
            event_type="match_found",
            title="Match found",
            body="A compatible learner is ready. Join your session now.",
            metadata={"session_id": session.id, "peer_id": user_id, "session_type": mode},
            commit=False,
        )

        redis_session = {
            "id": session.id,
            "user_a_id": user_id,
            "user_b_id": peer_id,
            "session_type": mode,
            "status": "active",
            "started_at": datetime.now(UTC).isoformat(),
        }
        if _redis_enabled():
            try:
                redis = get_redis_client()
                await redis.set(_session_key(session.id), json.dumps(redis_session), ex=settings.redis_session_ttl_seconds)
            except RedisConnectionError:
                _mark_redis_unavailable()
        matches_created += 1

    if matches_created > 0:
        await db.commit()

    return matches_created


async def get_active_session_for_user(db: AsyncSession, user_id: int) -> RealtimeSession | None:
    return await _active_session_for_user(db, user_id)


async def get_active_peer_id(db: AsyncSession, user_id: int) -> int | None:
    session = await _active_session_for_user(db, user_id)
    if not session:
        return None
    if session.user_a_id == user_id:
        return session.user_b_id
    return session.user_a_id


async def cleanup_disconnected_user(db: AsyncSession, user_id: int) -> None:
    await leave_queue(user_id)
    await set_presence(user_id, "offline")

    session = await _active_session_for_user(db, user_id)
    if not session:
        return

    await publish_user_event(session.user_a_id, build_event("USER_DISCONNECTED", {"user_id": user_id, "session_id": session.id}))
    await publish_user_event(session.user_b_id, build_event("USER_DISCONNECTED", {"user_id": user_id, "session_id": session.id}))


async def sweep_inactive_queue_users(timeout_seconds: int) -> int:
    settings = get_settings()
    now = datetime.now(UTC)
    removed = 0

    if _redis_enabled():
        try:
            redis = get_redis_client()
            queued_user_ids = await redis.zrange(settings.redis_queue_key, 0, 500)
        except RedisConnectionError:
            _mark_redis_unavailable()
            queued_user_ids = [str(ticket["user_id"]) for ticket in get_queue_tickets()]
    else:
        queued_user_ids = [str(ticket["user_id"]) for ticket in get_queue_tickets()]
    for raw_user_id in queued_user_ids:
        try:
            user_id = int(raw_user_id)
        except ValueError:
            if _redis_enabled():
                try:
                    redis = get_redis_client()
                    await redis.zrem(settings.redis_queue_key, raw_user_id)
                except RedisConnectionError:
                    _mark_redis_unavailable()
                    delete_queue_ticket(user_id)
            continue

        if _redis_enabled():
            try:
                redis = get_redis_client()
                presence = await redis.hgetall(_presence_key(user_id))
            except RedisConnectionError:
                _mark_redis_unavailable()
                presence = get_presence(user_id) or {}
        else:
            presence = get_presence(user_id) or {}

        if not presence:
            await leave_queue(user_id)
            await set_presence(user_id, "offline")
            removed += 1
            continue

        last_seen = presence.get("last_seen")
        if not last_seen:
            await leave_queue(user_id)
            await set_presence(user_id, "offline")
            removed += 1
            continue

        try:
            seen_at = datetime.fromisoformat(last_seen)
        except ValueError:
            await leave_queue(user_id)
            await set_presence(user_id, "offline")
            removed += 1
            continue

        if seen_at.tzinfo is None:
            seen_at = seen_at.replace(tzinfo=UTC)

        if (now - seen_at).total_seconds() > timeout_seconds:
            await leave_queue(user_id)
            await set_presence(user_id, "offline")
            await publish_user_event(
                user_id,
                build_event(
                    "USER_DISCONNECTED",
                    {
                        "user_id": user_id,
                        "reason": "heartbeat_timeout",
                    },
                ),
            )
            removed += 1

    return removed
