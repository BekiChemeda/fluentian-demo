from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class DelfMockTest(Base):
    __tablename__ = "delf_mock_tests"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    level: Mapped[str] = mapped_column(String(8), nullable=False, index=True)
    description: Mapped[str] = mapped_column(String(500), default="", nullable=False)
    questions_json: Mapped[str] = mapped_column(Text, nullable=False)
    passing_score: Mapped[int] = mapped_column(Integer, default=70, nullable=False)


class DelfMockResult(Base):
    __tablename__ = "delf_mock_results"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    test_id: Mapped[int] = mapped_column(ForeignKey("delf_mock_tests.id", ondelete="CASCADE"), index=True)
    score: Mapped[int] = mapped_column(Integer, nullable=False)
    correct_count: Mapped[int] = mapped_column(Integer, nullable=False)
    total_questions: Mapped[int] = mapped_column(Integer, nullable=False)
    answers_json: Mapped[str] = mapped_column(Text, nullable=False)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
