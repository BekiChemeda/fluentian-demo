from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


class QueueJoinPayload(BaseModel):
    preferred_mode: Literal["text", "audio"] = "text"
    learning_intent: str = Field(default="casual", min_length=2, max_length=64)
    cefr_level: Literal["A1", "A2", "B1", "B2", "C1", "C2"] = "A1"
    recording_consent: bool = False


class QueueLeavePayload(BaseModel):
    reason: str = "user_cancel"


class RealtimeEnvelope(BaseModel):
    type: Literal[
        "JOIN_QUEUE",
        "LEAVE_QUEUE",
        "MATCH_PROGRESS",
        "MATCH_FOUND",
        "SESSION_INITIALIZED",
        "SESSION_STARTED",
        "SESSION_ACTIVE",
        "SESSION_ENDED",
        "USER_DISCONNECTED",
        "CHAT_MESSAGE",
        "WEBRTC_OFFER",
        "WEBRTC_ANSWER",
        "WEBRTC_ICE_CANDIDATE",
        "CALL_INVITE",
        "CALL_HANGUP",
        "CALL_MUTE_TOGGLED",
        "ERROR_EVENT",
    ]
    timestamp: datetime
    payload: dict[str, Any] = Field(default_factory=dict)


class SessionEndRequest(BaseModel):
    session_id: int
    duration: int = Field(ge=0)
    ended_by: int


class SessionReportRequest(BaseModel):
    session_id: int
    reported_user_id: int
    reason: Literal["abuse", "inappropriate_behavior", "spam", "other"]


class UserStatsResponse(BaseModel):
    today: int
    yesterday: int
    weekly: int
    total_sessions: int
    average_session_duration: float
    last_active_time: datetime | None


class SessionSummaryResponse(BaseModel):
    session_id: int
    participants: list[int]
    session_type: str
    start_time: datetime
    end_time: datetime | None
    duration: int
    status: str
    recording_url: str | None
    report_flag: bool
