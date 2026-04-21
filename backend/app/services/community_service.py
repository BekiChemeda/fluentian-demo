import json
import re
from datetime import UTC, datetime

import httpx
from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.models.chat_message import ChatMessage
from app.models.cultural_topic import CulturalTopic
from app.models.match_pair import MatchPair
from app.models.match_presence import MatchPresence
from app.models.user import User
from app.schemas.community import AIChatResponse, AIChatTurn
from app.services.safety_service import is_user_blocked_pair


DEFAULT_CULTURAL_TOPICS: list[dict] = [
    {
        "title": "Food",
        "subtitle": "Compare injera and baguette table culture.",
        "hero_title": "France ↔ Ethiopia: Food Stories",
        "image_placeholder": "food_exchange.jpg",
        "cultural_cards": [
            "In Ethiopia, shared injera often signals hospitality.",
            "In France, course order shapes meal rhythm.",
            "Practice polite requests before discussing preferences.",
        ],
        "starter_prompts": [
            "Comment decrirais-tu un repas familial en Ethiopie ?",
            "Quelle est la difference entre un petit-dejeuner francais et ethiopien ?",
        ],
        "order_index": 1,
    },
    {
        "title": "Greetings",
        "subtitle": "Practice polite openings for French conversations.",
        "hero_title": "Openings and Respect",
        "image_placeholder": "greetings_exchange.jpg",
        "cultural_cards": [
            "Register matters: tu vs vous in first meetings.",
            "Greeting length can reflect relationship closeness.",
            "Body language and tone can shift meaning.",
        ],
        "starter_prompts": [
            "Comment saluerais-tu un professeur en France ?",
            "Dans quelles situations utilises-tu vous ?",
        ],
        "order_index": 2,
    },
    {
        "title": "Lifestyle",
        "subtitle": "Talk about routines in Addis Ababa and Paris.",
        "hero_title": "Daily Life Across Cities",
        "image_placeholder": "lifestyle_exchange.jpg",
        "cultural_cards": [
            "Commute habits influence daily vocabulary.",
            "Work-life schedules differ by region and profession.",
            "Weekend activities reveal social norms.",
        ],
        "starter_prompts": [
            "A quoi ressemble une journee typique a Addis-Abeba ?",
            "Comment les Parisiens organisent-ils leur soiree ?",
        ],
        "order_index": 3,
    },
    {
        "title": "Traditions",
        "subtitle": "Explore celebrations and family customs.",
        "hero_title": "Festivals and Family Traditions",
        "image_placeholder": "traditions_exchange.jpg",
        "cultural_cards": [
            "Holiday phrases can carry deep cultural context.",
            "Family roles may shape invitation language.",
            "Respectful curiosity improves cultural conversations.",
        ],
        "starter_prompts": [
            "Quelle tradition familiale est importante chez toi ?",
            "Comment celebrerais-tu une fete avec des amis francais ?",
        ],
        "order_index": 4,
    },
]


def _extract_json_payload(text: str) -> dict:
    raw = text.strip()
    if raw.startswith("```"):
        raw = raw.strip("`")
        if raw.startswith("json"):
            raw = raw[4:].strip()
    start = raw.find("{")
    end = raw.rfind("}")
    if start != -1 and end != -1 and end > start:
        raw = raw[start : end + 1]
    try:
        parsed = json.loads(raw)
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    return {}


async def generate_with_gemini(
    prompt: str,
    *,
    temperature: float = 0.2,
    max_output_tokens: int = 220,
    response_mime_type: str = "application/json",
) -> str:
    settings = get_settings()
    if not settings.gemini_api_key:
        raise AppException(
            "Gemini key missing",
            status_code=500,
            code="missing_gemini_key",
        )

    url = (
        "https://generativelanguage.googleapis.com/v1beta/models/"
        f"{settings.gemini_model}:generateContent?key={settings.gemini_api_key}"
    )
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_output_tokens,
            "responseMimeType": response_mime_type,
        },
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.post(url, json=payload)
        response.raise_for_status()
        data = response.json()
    return (
        data.get("candidates", [{}])[0]
        .get("content", {})
        .get("parts", [{}])[0]
        .get("text", "")
    )


async def _get_or_create_presence(db: AsyncSession, user_id: int) -> MatchPresence:
    presence_result = await db.execute(select(MatchPresence).where(MatchPresence.user_id == user_id))
    presence = presence_result.scalar_one_or_none()
    if presence is None:
        presence = MatchPresence(user_id=user_id, looking=False, updated_at=datetime.now(UTC))
        db.add(presence)
        await db.flush()
    return presence


async def _get_active_pair_for_user(db: AsyncSession, user_id: int) -> MatchPair | None:
    pair_result = await db.execute(
        select(MatchPair).where(
            MatchPair.active.is_(True),
            or_(MatchPair.user_a_id == user_id, MatchPair.user_b_id == user_id),
        )
    )
    return pair_result.scalar_one_or_none()


def _peer_id(pair: MatchPair, user_id: int) -> int:
    return pair.user_b_id if pair.user_a_id == user_id else pair.user_a_id


async def find_match(db: AsyncSession, user: User) -> User:
    pair = await _get_active_pair_for_user(db, user.id)
    if pair is not None:
        peer_id = _peer_id(pair, user.id)
        peer_result = await db.execute(select(User).where(User.id == peer_id))
        peer = peer_result.scalar_one_or_none()
        if peer is not None:
            return peer

    presence = await _get_or_create_presence(db, user.id)
    presence.looking = True
    presence.updated_at = datetime.now(UTC)

    waiting_result = await db.execute(
        select(MatchPresence)
        .where(MatchPresence.user_id != user.id, MatchPresence.looking.is_(True))
        .order_by(func.random())
        .limit(25)
    )
    waiters = waiting_result.scalars().all()
    waiting = None
    for candidate in waiters:
        if not await is_user_blocked_pair(db, user.id, candidate.user_id):
            waiting = candidate
            break

    if waiting is None:
        await db.commit()
        raise AppException("No match found yet", status_code=404, code="no_match")

    existing_pair = await _get_active_pair_for_user(db, waiting.user_id)
    if existing_pair is not None:
        await db.commit()
        raise AppException("No match found yet", status_code=404, code="no_match")

    new_pair = MatchPair(
        user_a_id=user.id,
        user_b_id=waiting.user_id,
        active=True,
        created_at=datetime.now(UTC),
    )
    db.add(new_pair)

    waiting.looking = False
    waiting.updated_at = datetime.now(UTC)
    presence.looking = False
    presence.updated_at = datetime.now(UTC)

    await db.commit()

    peer_result = await db.execute(select(User).where(User.id == waiting.user_id))
    peer = peer_result.scalar_one_or_none()
    if peer is None:
        raise AppException("No match found yet", status_code=404, code="no_match")
    return peer


async def get_match_status(db: AsyncSession, user: User) -> tuple[str, User | None]:
    pair = await _get_active_pair_for_user(db, user.id)
    if pair is not None:
        peer_result = await db.execute(select(User).where(User.id == _peer_id(pair, user.id)))
        peer = peer_result.scalar_one_or_none()
        return ("matched", peer)

    presence = await _get_or_create_presence(db, user.id)
    if presence.looking:
        return ("searching", None)
    return ("idle", None)


async def leave_matchmaking(db: AsyncSession, user: User) -> None:
    presence = await _get_or_create_presence(db, user.id)
    presence.looking = False
    presence.updated_at = datetime.now(UTC)

    pair = await _get_active_pair_for_user(db, user.id)
    if pair is not None:
        pair.active = False
        peer_presence = await _get_or_create_presence(db, _peer_id(pair, user.id))
        peer_presence.looking = False
        peer_presence.updated_at = datetime.now(UTC)

    await db.commit()


async def _assert_active_match(db: AsyncSession, user_id: int, peer_id: int) -> None:
    if await is_user_blocked_pair(db, user_id, peer_id):
        raise AppException("Chat disabled due to block policy", status_code=403, code="chat_blocked")

    pair_result = await db.execute(
        select(MatchPair).where(
            MatchPair.active.is_(True),
            or_(
                and_(MatchPair.user_a_id == user_id, MatchPair.user_b_id == peer_id),
                and_(MatchPair.user_a_id == peer_id, MatchPair.user_b_id == user_id),
            ),
        )
    )
    pair = pair_result.scalar_one_or_none()
    if pair is None:
        raise AppException("You can only chat with your current match", status_code=403, code="chat_not_allowed")


async def send_chat_message(db: AsyncSession, sender: User, receiver_id: int, body: str) -> ChatMessage:
    receiver_result = await db.execute(select(User).where(User.id == receiver_id))
    receiver = receiver_result.scalar_one_or_none()
    if not receiver:
        raise AppException("Receiver not found", status_code=404, code="receiver_not_found")

    await _assert_active_match(db, sender.id, receiver_id)

    message = ChatMessage(
        sender_id=sender.id,
        receiver_id=receiver_id,
        body=body,
        created_at=datetime.now(UTC),
    )
    db.add(message)
    await db.commit()
    await db.refresh(message)
    return message


async def list_chat_messages(db: AsyncSession, user: User, peer_id: int, limit: int = 100) -> list[ChatMessage]:
    await _assert_active_match(db, user.id, peer_id)
    result = await db.execute(
        select(ChatMessage)
        .where(
            or_(
                and_(ChatMessage.sender_id == user.id, ChatMessage.receiver_id == peer_id),
                and_(ChatMessage.sender_id == peer_id, ChatMessage.receiver_id == user.id),
            )
        )
        .order_by(ChatMessage.created_at.asc())
        .limit(limit)
    )
    return result.scalars().all()


def _serialize_history(history: list[AIChatTurn] | None) -> str:
    if not history:
        return "(none)"

    settings = get_settings()
    trimmed = history[-settings.ai_context_turn_limit :]
    lines = [f"{item.role}: {item.message}" for item in trimmed]
    return "\n".join(lines)


def _looks_like_prompt_injection(text: str) -> bool:
    patterns = [
        r"ignore\s+previous\s+instructions",
        r"reveal\s+system\s+prompt",
        r"developer\s+message",
        r"jailbreak",
        r"bypass\s+safety",
    ]
    lowered = text.lower()
    return any(re.search(pattern, lowered) for pattern in patterns)


async def ai_chat(
    body: str,
    history: list[AIChatTurn] | None = None,
    base_language: str = "Amharic",
) -> AIChatResponse:
    settings = get_settings()

    if _looks_like_prompt_injection(body):
        return AIChatResponse(
            reply="Je ne peux pas traiter cette requete. Reformulez une question de francais simple.",
            correction=None,
            corrected=False,
            success=False,
            error_code="unsafe_prompt",
            error_message="Prompt rejected by safety guardrails",
        )

    if not settings.gemini_api_key:
        return AIChatResponse(
            reply="Je peux discuter en francais. Ajoute la cle Gemini pour une reponse IA complete.",
            correction=None,
            corrected=False,
            success=False,
            error_code="missing_gemini_key",
            error_message="GEMINI_API_KEY is not configured on backend",
        )

    recent_context = _serialize_history(history)
    prompt = (
        "You are a French conversation coach. Respond in French only by default. "
        "If and only if the user explicitly asks for explanation in English or Amharic, then explain in that requested language. "
        f"If the user asks for explanation but does not specify a language, explain in this base language: {base_language}. "
        "Return strict JSON with keys: reply, corrected, correction. "
        "If user input is not in French OR has grammar/spelling errors, set corrected=true and provide the corrected French sentence in correction. "
        "If no correction needed, set corrected=false and correction=null. "
        f"Recent conversation context:\n{recent_context}\n"
        f"User message: {body}"
    )

    try:
        text = await generate_with_gemini(
            prompt,
            temperature=0.2,
            max_output_tokens=220,
            response_mime_type="application/json",
        )
        parsed = _extract_json_payload(text)
        reply = str(parsed.get("reply") or "Pouvez-vous reformuler votre message, s'il vous plait ?")
        corrected = bool(parsed.get("corrected", False))
        correction = parsed.get("correction")
        if correction is not None:
            correction = str(correction)
        return AIChatResponse(
            reply=reply,
            corrected=corrected,
            correction=correction,
            success=True,
            error_code=None,
            error_message=None,
        )
    except Exception:
        return AIChatResponse(
            reply="Desole, je ne peux pas repondre maintenant. Reessayons dans un instant.",
            correction=None,
            corrected=False,
            success=False,
            error_code="gemini_unavailable",
            error_message="Gemini request failed or timed out",
        )


async def list_cultural_topics(db: AsyncSession) -> list[CulturalTopic]:
    result = await db.execute(
        select(CulturalTopic)
        .where(CulturalTopic.active.is_(True))
        .order_by(CulturalTopic.order_index.asc())
    )
    return result.scalars().all()
