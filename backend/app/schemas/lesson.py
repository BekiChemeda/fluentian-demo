from typing import Literal

from pydantic import BaseModel, Field


class DialogueLine(BaseModel):
    speaker: str
    text: str
    mine: bool = False


class LessonBlock(BaseModel):
    type: Literal[
        "dialogue",
        "sentence",
        "ordering",
        "translation_mcq",
        "cloze",
        "matching",
        "phonetic_analysis",
        "cultural_insight",
        "transformation",
        "logic_analysis",
        "mathematical_analysis",
    ]
    title: str
    hint: str = ""
    base_explanation: str = ""
    explanation_placement: Literal["top", "middle", "bottom"] = "middle"
    has_question: bool = True
    answer: str = ""
    choices: list[str] = Field(default_factory=list)
    tokens: list[str] = Field(default_factory=list)
    dialogue: list[DialogueLine] = Field(default_factory=list)


class LessonContent(BaseModel):
    blocks: list[LessonBlock] = Field(default_factory=list)

    # Legacy fields are still accepted for backward compatibility.
    question: str | None = None
    prompt_language: str | None = None
    source: str | None = None
    target: str | None = None
    choices: list[str] | None = None
    answer: str | None = None

    model_config = {"extra": "allow"}


class LessonResponse(BaseModel):
    id: int
    level: str
    type: str
    content: LessonContent
    xp_reward: int
    order_index: int
    completed: bool = False
    unlocked: bool = False

    model_config = {"from_attributes": True}


class LessonListResponse(BaseModel):
    items: list[LessonResponse]
    page: int
    page_size: int
    total: int


class CompleteLessonRequest(BaseModel):
    score: int


class CompleteLessonResponse(BaseModel):
    lesson_id: int
    completed: bool
    score: int
    xp_earned: int
    total_xp: int
    streak: int


class LessonExplainRequest(BaseModel):
    block_title: str
    block_hint: str = ""
    block_answer: str = ""
    action: str = "default"
    inline_context: str | None = None


class LessonExplainResponse(BaseModel):
    simple: str
    examples: list[str] = Field(default_factory=list)
    rules: list[str] = Field(default_factory=list)
