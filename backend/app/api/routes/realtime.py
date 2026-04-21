import asyncio
import json
from typing import Annotated

from fastapi import APIRouter, Depends, Header, WebSocket, WebSocketDisconnect, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from redis.exceptions import ConnectionError as RedisConnectionError

from app.api.deps import get_current_user
from app.core.config import get_settings
from app.core.exceptions import AppException
from app.core.redis_client import get_redis_client
from app.core.security import decode_token
from app.db.session import AsyncSessionLocal, get_db
from app.models.user import User
from app.core.realtime_fallback import get_event_queue
from app.schemas.realtime import QueueJoinPayload, SessionEndRequest, SessionReportRequest, SessionSummaryResponse, UserStatsResponse
from app.services.realtime_service import (
    build_event,
    cleanup_disconnected_user,
    get_active_peer_id,
    join_queue,
    leave_queue,
    process_matchmaking_once,
    publish_user_event,
    refresh_heartbeat,
    set_presence,
)
from app.services.idempotency_service import fingerprint_payload, get_saved_response, save_response
from app.services.notification_service import create_notification
from app.services.session_service import end_session, get_user_stats, report_user

router = APIRouter(prefix="", tags=["realtime"])

DbDep = Annotated[AsyncSession, Depends(get_db)]
CurrentUserDep = Annotated[User, Depends(get_current_user)]
IdempotencyKeyHeader = Annotated[str | None, Header(alias="Idempotency-Key")]


@router.post("/queue/join")
async def queue_join(
    payload: QueueJoinPayload,
    db: DbDep,
    user: CurrentUserDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> dict[str, str | int]:
    request_payload = payload.model_dump(mode="json")
    if idempotency_key:
        request_hash = fingerprint_payload(request_payload)
        saved = await get_saved_response(
            db,
            user_id=user.id,
            route="POST:/queue/join",
            key=idempotency_key,
            request_hash=request_hash,
        )
        if saved:
            saved_payload, _ = saved
            return saved_payload

    await join_queue(user, payload)
    await process_matchmaking_once(db)
    response_payload = {"status": "queued", "user_id": user.id}
    if idempotency_key:
        await save_response(
            db,
            user_id=user.id,
            route="POST:/queue/join",
            key=idempotency_key,
            request_hash=request_hash,
            response_payload=response_payload,
        )
    return response_payload


@router.post("/queue/leave")
async def queue_leave(
    db: DbDep,
    user: CurrentUserDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> dict[str, str | int]:
    request_hash = fingerprint_payload({"user_id": user.id})
    if idempotency_key:
        saved = await get_saved_response(
            db,
            user_id=user.id,
            route="POST:/queue/leave",
            key=idempotency_key,
            request_hash=request_hash,
        )
        if saved:
            saved_payload, _ = saved
            return saved_payload

    await leave_queue(user.id)
    response_payload = {"status": "left", "user_id": user.id}
    if idempotency_key:
        await save_response(
            db,
            user_id=user.id,
            route="POST:/queue/leave",
            key=idempotency_key,
            request_hash=request_hash,
            response_payload=response_payload,
        )
    return response_payload


async def _resolve_ws_user(token: str) -> User:
    payload = decode_token(token, expected_type="access")
    user_id = int(payload["sub"])
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise AppException("User not found", status_code=404, code="user_not_found")
        return user


async def _forward_pubsub_messages(websocket: WebSocket, user_id: int) -> None:
    settings = get_settings()
    channel = f"{settings.redis_user_events_prefix}:{user_id}"
    try:
        redis = get_redis_client()
        pubsub = redis.pubsub()
        await pubsub.subscribe(channel)
        try:
            while True:
                message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                if not message:
                    await asyncio.sleep(0.05)
                    continue

                raw_data = message.get("data")
                if raw_data is None:
                    continue

                if isinstance(raw_data, bytes):
                    raw_data = raw_data.decode("utf-8")
                try:
                    event = json.loads(raw_data)
                except (TypeError, json.JSONDecodeError):
                    continue

                await websocket.send_json(event)
        finally:
            await pubsub.unsubscribe(channel)
            await pubsub.close()
    except RedisConnectionError:
        queue = get_event_queue(user_id)
        while True:
            event = await queue.get()
            await websocket.send_json(event)


@router.websocket("/ws/match")
async def match_socket(websocket: WebSocket) -> None:
    token = websocket.query_params.get("token")
    if not token:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    try:
        user = await _resolve_ws_user(token)
    except AppException:
        await websocket.close(code=status.WS_1008_POLICY_VIOLATION)
        return

    await websocket.accept()
    await set_presence(user.id, "online")

    forward_task = asyncio.create_task(_forward_pubsub_messages(websocket, user.id))
    try:
        while True:
            incoming = await websocket.receive_json()
            event_type = str(incoming.get("type", "")).upper()
            payload = incoming.get("payload") or {}

            if event_type == "JOIN_QUEUE":
                queue_payload = QueueJoinPayload.model_validate(payload)
                async with AsyncSessionLocal() as db:
                    await join_queue(user, queue_payload)
                    matches = await process_matchmaking_once(db)
                await websocket.send_json(
                    build_event(
                        "MATCH_PROGRESS",
                        {
                            "status": "searching",
                            "matches_created": matches,
                            "queue_joined": True,
                        },
                    ).model_dump(mode="json")
                )
            elif event_type == "LEAVE_QUEUE":
                await leave_queue(user.id)
                await websocket.send_json(
                    build_event(
                        "MATCH_PROGRESS",
                        {
                            "status": "idle",
                            "queue_joined": False,
                        },
                    ).model_dump(mode="json")
                )
            elif event_type == "MATCH_PROGRESS":
                await refresh_heartbeat(user.id)
            elif event_type in {
                "WEBRTC_OFFER",
                "WEBRTC_ANSWER",
                "WEBRTC_ICE_CANDIDATE",
                "CALL_INVITE",
                "CALL_HANGUP",
                "CALL_MUTE_TOGGLED",
            }:
                async with AsyncSessionLocal() as db:
                    peer_id = await get_active_peer_id(db, user.id)
                if peer_id is None:
                    await websocket.send_json(
                        build_event(
                            "ERROR_EVENT",
                            {
                                "reason": "no_active_session",
                                "event_type": event_type,
                            },
                        ).model_dump(mode="json")
                    )
                    continue

                await publish_user_event(
                    peer_id,
                    build_event(
                        event_type,
                        {
                            "from_user_id": user.id,
                            "session_signal": payload,
                        },
                    ),
                )
                if event_type == "CALL_INVITE":
                    await create_notification(
                        db,
                        user_id=peer_id,
                        event_type="call_invite",
                        title="Incoming audio call",
                        body=f"{user.email} invited you to an audio session.",
                        metadata={"from_user_id": user.id},
                    )
            elif event_type == "USER_DISCONNECTED":
                await set_presence(user.id, "offline")
            else:
                await websocket.send_json(
                    build_event(
                        "ERROR_EVENT",
                        {
                            "reason": "unsupported_event",
                            "event_type": event_type,
                        },
                    ).model_dump(mode="json")
                )
    except WebSocketDisconnect:
        async with AsyncSessionLocal() as db:
            await cleanup_disconnected_user(db, user.id)
    finally:
        forward_task.cancel()


@router.post("/session/end", response_model=SessionSummaryResponse)
async def end_current_session(
    payload: SessionEndRequest,
    db: DbDep,
    user: CurrentUserDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> SessionSummaryResponse:
    request_payload = payload.model_dump(mode="json")
    if idempotency_key:
        request_hash = fingerprint_payload(request_payload)
        saved = await get_saved_response(
            db,
            user_id=user.id,
            route="POST:/session/end",
            key=idempotency_key,
            request_hash=request_hash,
        )
        if saved:
            saved_payload, _ = saved
            return SessionSummaryResponse.model_validate(saved_payload)

    response = await end_session(db, user, payload)
    if idempotency_key:
        await save_response(
            db,
            user_id=user.id,
            route="POST:/session/end",
            key=idempotency_key,
            request_hash=request_hash,
            response_payload=response.model_dump(mode="json"),
        )
    return response


@router.post("/session/report")
async def report_session_user(
    payload: SessionReportRequest,
    db: DbDep,
    user: CurrentUserDep,
    idempotency_key: IdempotencyKeyHeader = None,
) -> dict[str, str]:
    request_payload = payload.model_dump(mode="json")
    if idempotency_key:
        request_hash = fingerprint_payload(request_payload)
        saved = await get_saved_response(
            db,
            user_id=user.id,
            route="POST:/session/report",
            key=idempotency_key,
            request_hash=request_hash,
        )
        if saved:
            saved_payload, _ = saved
            return saved_payload

    response = await report_user(db, user, payload)
    if idempotency_key:
        await save_response(
            db,
            user_id=user.id,
            route="POST:/session/report",
            key=idempotency_key,
            request_hash=request_hash,
            response_payload=response,
        )
    return response


@router.get("/user/stats", response_model=UserStatsResponse)
async def user_stats(db: DbDep, user: CurrentUserDep) -> UserStatsResponse:
    return await get_user_stats(db, user)
