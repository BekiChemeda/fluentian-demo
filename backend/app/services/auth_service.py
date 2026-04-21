from datetime import timedelta

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import AppException
from app.core.security import create_token, hash_password, verify_password
from app.models.user import User
from app.schemas.auth import LoginRequest, RegisterRequest, TokenPair

settings = get_settings()


async def register_user(payload: RegisterRequest, db: AsyncSession) -> TokenPair:
    existing = await db.execute(select(User).where(User.email == payload.email.lower()))
    if existing.scalar_one_or_none():
        raise AppException("Email already registered", status_code=409, code="email_exists")

    user = User(
        email=payload.email.lower(),
        password_hash=hash_password(payload.password),
        native_language=payload.native_language,
        target_language=payload.target_language,
        daily_xp_goal=payload.daily_xp_goal,
    )
    db.add(user)
    await db.commit()
    await db.refresh(user)
    return _build_token_pair(user.id)


async def login_user(payload: LoginRequest, db: AsyncSession) -> TokenPair:
    result = await db.execute(select(User).where(User.email == payload.email.lower()))
    user = result.scalar_one_or_none()
    if not user or not verify_password(payload.password, user.password_hash):
        raise AppException("Invalid credentials", status_code=401, code="invalid_credentials")
    return _build_token_pair(user.id)


def refresh_access_token(refresh_token: str) -> TokenPair:
    from app.core.security import decode_token

    payload = decode_token(refresh_token, expected_type="refresh")
    user_id = int(payload["sub"])
    return _build_token_pair(user_id)


def _build_token_pair(user_id: int) -> TokenPair:
    access_token = create_token(
        subject=str(user_id),
        token_type="access",
        expires_delta=timedelta(minutes=settings.access_token_expire_minutes),
    )
    refresh_token = create_token(
        subject=str(user_id),
        token_type="refresh",
        expires_delta=timedelta(days=settings.refresh_token_expire_days),
    )
    return TokenPair(access_token=access_token, refresh_token=refresh_token)
