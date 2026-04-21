import hashlib
import json
from datetime import UTC, datetime

from sqlalchemy.exc import IntegrityError
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import AppException
from app.models.idempotency_record import IdempotencyRecord


def fingerprint_payload(payload: dict) -> str:
    payload_text = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(payload_text.encode("utf-8")).hexdigest()


async def get_saved_response(
    db: AsyncSession,
    *,
    user_id: int,
    route: str,
    key: str,
    request_hash: str,
) -> tuple[dict, int] | None:
    result = await db.execute(
        select(IdempotencyRecord).where(
            IdempotencyRecord.user_id == user_id,
            IdempotencyRecord.route == route,
            IdempotencyRecord.key == key,
        )
    )
    record = result.scalar_one_or_none()
    if not record:
        return None

    if record.request_hash != request_hash:
        raise AppException(
            "Idempotency key reuse with different payload",
            status_code=409,
            code="idempotency_conflict",
        )

    try:
        payload = json.loads(record.response_json)
    except json.JSONDecodeError as exc:
        raise AppException(
            "Stored idempotency response is invalid",
            status_code=500,
            code="idempotency_store_corrupt",
        ) from exc
    if not isinstance(payload, dict):
        raise AppException(
            "Stored idempotency response has invalid shape",
            status_code=500,
            code="idempotency_store_corrupt",
        )

    return payload, record.status_code


async def save_response(
    db: AsyncSession,
    *,
    user_id: int,
    route: str,
    key: str,
    request_hash: str,
    response_payload: dict,
    status_code: int = 200,
) -> None:
    record = IdempotencyRecord(
        user_id=user_id,
        route=route,
        key=key,
        request_hash=request_hash,
        response_json=json.dumps(response_payload, separators=(",", ":")),
        status_code=status_code,
        created_at=datetime.now(UTC),
    )
    db.add(record)
    try:
        await db.commit()
    except IntegrityError:
        # A racing request may have persisted the same key first.
        await db.rollback()
