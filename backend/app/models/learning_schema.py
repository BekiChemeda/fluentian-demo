from datetime import datetime
from uuid import UUID, uuid4

from sqlalchemy import Boolean, DateTime, ForeignKey, Integer, JSON, Numeric, String, Text, UniqueConstraint, Uuid
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Language(Base):
    __tablename__ = "languages"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    iso_code: Mapped[str] = mapped_column(String(10), unique=True, index=True, nullable=False)
    english_name: Mapped[str] = mapped_column(String(120), nullable=False)
    native_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class Course(Base):
    __tablename__ = "courses"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    target_language_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("languages.id"), index=True)
    code: Mapped[str] = mapped_column(String(50), unique=True, index=True, nullable=False)
    level_min: Mapped[str] = mapped_column(String(8), nullable=False)
    level_max: Mapped[str] = mapped_column(String(8), nullable=False)
    is_published: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False, index=True)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    updated_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    published_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class CourseI18n(Base):
    __tablename__ = "course_i18n"
    __table_args__ = (UniqueConstraint("course_id", "language_id", name="uq_course_i18n_course_language"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    course_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), index=True)
    language_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("languages.id"), index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    subtitle: Mapped[str | None] = mapped_column(String(220), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)


class LearningPath(Base):
    __tablename__ = "learning_paths"
    __table_args__ = (UniqueConstraint("course_id", "path_version", name="uq_learning_paths_course_version"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    course_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("courses.id", ondelete="CASCADE"), index=True)
    path_version: Mapped[int] = mapped_column(Integer, default=1, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class PathUnit(Base):
    __tablename__ = "path_units"
    __table_args__ = (UniqueConstraint("learning_path_id", "unit_no", name="uq_path_units_path_unit_no"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    learning_path_id: Mapped[UUID] = mapped_column(
        Uuid(as_uuid=True),
        ForeignKey("learning_paths.id", ondelete="CASCADE"),
        index=True,
    )
    unit_kind: Mapped[str] = mapped_column(String(24), default="core", nullable=False)
    cefr_level: Mapped[str] = mapped_column(String(8), nullable=False, index=True)
    unit_no: Mapped[int] = mapped_column(Integer, nullable=False)
    crown_goal: Mapped[int] = mapped_column(Integer, default=5, nullable=False)
    min_mastery_to_unlock: Mapped[float] = mapped_column(Numeric(5, 2), default=0.60, nullable=False)
    guidebook_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class PathUnitI18n(Base):
    __tablename__ = "path_unit_i18n"
    __table_args__ = (UniqueConstraint("unit_id", "language_id", name="uq_path_unit_i18n_unit_language"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    unit_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("path_units.id", ondelete="CASCADE"), index=True)
    language_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("languages.id"), index=True)
    title: Mapped[str] = mapped_column(String(180), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)


class UnitLesson(Base):
    __tablename__ = "unit_lessons"
    __table_args__ = (
        UniqueConstraint("unit_id", "lesson_id", name="uq_unit_lessons_unit_lesson"),
        UniqueConstraint("unit_id", "sort_no", name="uq_unit_lessons_unit_sort"),
    )

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    unit_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("path_units.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[int] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    sort_no: Mapped[int] = mapped_column(Integer, nullable=False)
    is_optional: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)


class LessonBlockRecord(Base):
    __tablename__ = "lesson_blocks"
    __table_args__ = (UniqueConstraint("lesson_id", "sequence_no", name="uq_lesson_blocks_lesson_sequence"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    lesson_id: Mapped[int] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    block_kind: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    sequence_no: Mapped[int] = mapped_column(Integer, nullable=False)
    block_payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class Question(Base):
    __tablename__ = "questions"
    __table_args__ = (UniqueConstraint("lesson_id", "sequence_no", name="uq_questions_lesson_sequence"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    lesson_id: Mapped[int] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    question_kind: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    sequence_no: Mapped[int] = mapped_column(Integer, nullable=False)
    difficulty: Mapped[float] = mapped_column(Numeric(3, 2), default=0.50, nullable=False)
    prompt_payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    grading_payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    hint_payload: Mapped[dict | None] = mapped_column(JSON, nullable=True)
    created_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    updated_by: Mapped[int | None] = mapped_column(ForeignKey("users.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    updated_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class UserQuestionAttempt(Base):
    __tablename__ = "user_question_attempts"
    __table_args__ = (UniqueConstraint("user_id", "question_id", "attempt_no", name="uq_attempts_user_question_no"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[int] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    question_id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), ForeignKey("questions.id", ondelete="CASCADE"), index=True)
    attempt_no: Mapped[int] = mapped_column(Integer, nullable=False)
    answer_payload: Mapped[dict] = mapped_column(JSON, nullable=False)
    score: Mapped[float] = mapped_column(Numeric(5, 2), default=0, nullable=False)
    is_correct: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    latency_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    ai_feedback_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("ai_explanations.id"), nullable=True)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class UserLessonProgress(Base):
    __tablename__ = "user_lesson_progress"
    __table_args__ = (UniqueConstraint("user_id", "lesson_id", name="uq_user_lesson_progress_user_lesson"),)

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[int] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), index=True)
    status: Mapped[str] = mapped_column(String(30), default="in_progress", nullable=False, index=True)
    mastery_score: Mapped[float] = mapped_column(Numeric(5, 2), default=0, nullable=False)
    best_score: Mapped[float] = mapped_column(Numeric(5, 2), default=0, nullable=False)
    attempts_count: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_activity_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class ReviewQueueItem(Base):
    __tablename__ = "review_queue_items"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    source_lesson_id: Mapped[int | None] = mapped_column(ForeignKey("lessons.id", ondelete="CASCADE"), nullable=True)
    due_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
    priority: Mapped[int] = mapped_column(Integer, default=50, nullable=False)
    state: Mapped[str] = mapped_column(String(30), default="due", nullable=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)


class AIExplanation(Base):
    __tablename__ = "ai_explanations"

    id: Mapped[UUID] = mapped_column(Uuid(as_uuid=True), primary_key=True, default=uuid4)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    lesson_id: Mapped[int | None] = mapped_column(ForeignKey("lessons.id", ondelete="SET NULL"), nullable=True, index=True)
    question_id: Mapped[UUID | None] = mapped_column(Uuid(as_uuid=True), ForeignKey("questions.id"), nullable=True, index=True)
    source_type: Mapped[str] = mapped_column(String(40), nullable=False, index=True)
    source_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    base_language: Mapped[str] = mapped_column(String(64), nullable=False)
    target_language: Mapped[str] = mapped_column(String(64), nullable=False)
    user_input: Mapped[str | None] = mapped_column(Text, nullable=True)
    explanation_text: Mapped[str] = mapped_column(Text, nullable=False)
    cefr_level: Mapped[str | None] = mapped_column(String(8), nullable=True)
    model_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    tokens_in: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tokens_out: Mapped[int | None] = mapped_column(Integer, nullable=True)
    latency_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    quality_rating: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, index=True)
