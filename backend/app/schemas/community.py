from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class MatchResponse(BaseModel):
    id: int
    email: str
    xp: int
    streak: int


class SendChatRequest(BaseModel):
    receiver_id: int
    body: str = Field(min_length=1, max_length=1000)


class ChatMessageResponse(BaseModel):
    id: int
    sender_id: int
    receiver_id: int
    body: str
    created_at: datetime

    model_config = {"from_attributes": True}


class MatchPeer(BaseModel):
    id: int
    email: str
    xp: int
    streak: int


class MatchStatusResponse(BaseModel):
    status: Literal["searching", "matched", "idle"]
    peer: MatchPeer | None = None


class ChatListResponse(BaseModel):
    items: list[ChatMessageResponse]


class AIChatRequest(BaseModel):
    body: str = Field(min_length=1, max_length=1000)
    history: list["AIChatTurn"] = Field(default_factory=list)


class AIChatTurn(BaseModel):
    role: Literal["user", "assistant"]
    message: str = Field(min_length=1, max_length=1000)


class AIChatResponse(BaseModel):
    reply: str
    correction: str | None = None
    corrected: bool = False
    success: bool = True
    error_code: str | None = None
    error_message: str | None = None


class CulturalTopicResponse(BaseModel):
    id: int
    title: str
    subtitle: str
    hero_title: str
    image_placeholder: str
    cultural_cards: list[str] = Field(default_factory=list)
    starter_prompts: list[str] = Field(default_factory=list)
    order_index: int

    model_config = {"from_attributes": True}


class CulturalTopicsResponse(BaseModel):
    items: list[CulturalTopicResponse]
