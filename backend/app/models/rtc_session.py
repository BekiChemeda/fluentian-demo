from datetime import datetime

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class RealtimeSession(Base):
    __tablename__ = "realtime_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_a_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    user_b_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    session_type: Mapped[str] = mapped_column(String(16), default="text", nullable=False)
    status: Mapped[str] = mapped_column(String(24), default="active", nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    ended_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=True)
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    recording_url: Mapped[str] = mapped_column(String(1024), nullable=True)
    recording_consent_a: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    recording_consent_b: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    report_flag: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
