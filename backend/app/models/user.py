from datetime import date

from sqlalchemy import Date, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[str] = mapped_column(String(24), default="student", nullable=False, index=True)
    native_language: Mapped[str] = mapped_column(String(64), default="Amharic", nullable=False)
    target_language: Mapped[str] = mapped_column(String(64), default="French", nullable=False)
    xp: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    streak: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    last_active_date: Mapped[date] = mapped_column(Date, nullable=True)
    daily_xp_goal: Mapped[int] = mapped_column(Integer, default=20, nullable=False)
    cefr_level: Mapped[str] = mapped_column(String(8), default="A1", nullable=False)
    learning_intent: Mapped[str] = mapped_column(String(64), default="casual", nullable=False)
    preferred_mode: Mapped[str] = mapped_column(String(16), default="text", nullable=False)
    report_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    drop_rate: Mapped[float] = mapped_column(Float, default=0.0, nullable=False)
    avg_session_duration_seconds: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
