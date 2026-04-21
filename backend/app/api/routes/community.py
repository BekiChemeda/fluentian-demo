from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.community import (
    AIChatRequest,
    AIChatResponse,
    ChatListResponse,
    ChatMessageResponse,
    CulturalTopicResponse,
    CulturalTopicsResponse,
    MatchPeer,
    MatchResponse,
    MatchStatusResponse,
    SendChatRequest,
)
from app.services.community_service import (
    ai_chat,
    find_match,
    get_match_status,
    list_cultural_topics,
    leave_matchmaking,
    list_chat_messages,
    send_chat_message,
)
from app.services.notification_service import create_notification
from app.services.realtime_service import build_event, publish_user_event

router = APIRouter(prefix="", tags=["community"])


@router.get("/match", response_model=MatchResponse)
async def match(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> MatchResponse:
    peer = await find_match(db, user)
    return MatchResponse(id=peer.id, email=peer.email, xp=peer.xp, streak=peer.streak)


@router.get("/match/status", response_model=MatchStatusResponse)
async def match_status(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> MatchStatusResponse:
    status, peer = await get_match_status(db, user)
    if peer is None:
        return MatchStatusResponse(status=status, peer=None)
    return MatchStatusResponse(
        status=status,
        peer=MatchPeer(id=peer.id, email=peer.email, xp=peer.xp, streak=peer.streak),
    )


@router.post("/match/leave")
async def leave_match(db: AsyncSession = Depends(get_db), user: User = Depends(get_current_user)) -> dict[str, str]:
    await leave_matchmaking(db, user)
    return {"status": "ok"}


@router.post("/chat/send", response_model=ChatMessageResponse)
async def send_chat(
    payload: SendChatRequest,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ChatMessageResponse:
    msg = await send_chat_message(db, user, payload.receiver_id, payload.body)
    event_payload = {
        "id": msg.id,
        "sender_id": msg.sender_id,
        "receiver_id": msg.receiver_id,
        "body": msg.body,
        "created_at": msg.created_at.isoformat(),
    }
    await publish_user_event(payload.receiver_id, build_event("CHAT_MESSAGE", event_payload))
    await publish_user_event(user.id, build_event("CHAT_MESSAGE", event_payload))
    await create_notification(
        db,
        user_id=payload.receiver_id,
        event_type="chat_message",
        title="New message",
        body="You received a new community chat message.",
        metadata={"sender_id": user.id, "message_id": msg.id},
    )
    return ChatMessageResponse.model_validate(msg)


@router.get("/chat/messages", response_model=ChatListResponse)
async def chat_messages(
    peer_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ChatListResponse:
    items = await list_chat_messages(db, user, peer_id)
    return ChatListResponse(items=[ChatMessageResponse.model_validate(item) for item in items])


@router.post("/chat/ai", response_model=AIChatResponse)
async def chat_ai(payload: AIChatRequest, user: User = Depends(get_current_user)) -> AIChatResponse:
    return await ai_chat(payload.body, payload.history, user.native_language)


@router.get("/cultural/topics", response_model=CulturalTopicsResponse)
async def cultural_topics(
    db: AsyncSession = Depends(get_db),
    _: User = Depends(get_current_user),
) -> CulturalTopicsResponse:
    items = await list_cultural_topics(db)
    return CulturalTopicsResponse(items=[CulturalTopicResponse.model_validate(item) for item in items])
