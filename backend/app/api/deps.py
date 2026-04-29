from datetime import UTC, date

from fastapi import Depends
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import decode_token
from app.db.session import get_db
from app.models.user import User
from app.core.exceptions import AppException

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")


async def get_current_user(
    db: AsyncSession = Depends(get_db),
    token: str = Depends(oauth2_scheme),
) -> User:
    payload = decode_token(token, expected_type="access")
    user_id = int(payload["sub"])
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise AppException("User not found", status_code=404, code="user_not_found")

    today = date.today()
    if user.last_active_date:
        days_diff = (today - user.last_active_date).days
        if days_diff > 1:
            user.streak = 0
    user.last_active_date = today
    await db.commit()
    await db.refresh(user)
    return user


def require_roles(*roles: str):
    async def dependency(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise AppException("Insufficient permissions", status_code=403, code="forbidden")
        return user

    return dependency
