from sqlalchemy import Boolean, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class CulturalTopic(Base):
    __tablename__ = "cultural_topics"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    title: Mapped[str] = mapped_column(String(80), nullable=False)
    subtitle: Mapped[str] = mapped_column(String(300), nullable=False)
    hero_title: Mapped[str] = mapped_column(String(120), nullable=False)
    image_placeholder: Mapped[str] = mapped_column(String(120), nullable=False)
    cultural_cards: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    starter_prompts: Mapped[list[str]] = mapped_column(JSON, nullable=False, default=list)
    order_index: Mapped[int] = mapped_column(Integer, nullable=False, index=True)
    active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True, index=True)