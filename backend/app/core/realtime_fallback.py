from __future__ import annotations

import asyncio
from collections import defaultdict
from datetime import UTC, datetime


_fallback_events: dict[int, asyncio.Queue[dict]] = defaultdict(asyncio.Queue)
_fallback_queue: dict[int, dict] = {}
_fallback_presence: dict[int, dict[str, str]] = {}


def get_event_queue(user_id: int) -> asyncio.Queue[dict]:
    return _fallback_events[user_id]


def set_queue_ticket(user_id: int, ticket: dict) -> None:
    _fallback_queue[user_id] = ticket


def get_queue_tickets() -> list[dict]:
    return list(_fallback_queue.values())


def delete_queue_ticket(user_id: int) -> None:
    _fallback_queue.pop(user_id, None)


def get_ticket(user_id: int) -> dict | None:
    return _fallback_queue.get(user_id)


def set_presence(user_id: int, status: str, session_id: int | None = None) -> None:
    _fallback_presence[user_id] = {
        "status": status,
        "last_seen": datetime.now(UTC).isoformat(),
        "session_id": str(session_id or ""),
    }


def get_presence(user_id: int) -> dict[str, str] | None:
    return _fallback_presence.get(user_id)


def clear_user(user_id: int) -> None:
    _fallback_presence.pop(user_id, None)
    _fallback_queue.pop(user_id, None)
    _fallback_events.pop(user_id, None)