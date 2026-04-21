from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.user import User
from app.schemas.recording import RecordingListResponse, RecordingResponse
from app.services.recording_service import get_session_recording, list_user_recordings

router = APIRouter(prefix="/recordings", tags=["recordings"])


@router.get("", response_model=RecordingListResponse)
async def list_recordings(
    limit: int = Query(default=50, ge=1, le=200),
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RecordingListResponse:
    rows = await list_user_recordings(db, user, limit=limit)
    return RecordingListResponse(
        items=[
            RecordingResponse(
                session_id=row.session_id,
                recording_url=row.recording_url,
                expires_at=row.expires_at,
            )
            for row in rows
        ]
    )


@router.get("/{session_id}", response_model=RecordingResponse)
async def session_recording(
    session_id: int,
    db: AsyncSession = Depends(get_db),
    user: User = Depends(get_current_user),
) -> RecordingResponse:
    row = await get_session_recording(db, user, session_id)
    return RecordingResponse(
        session_id=row.session_id,
        recording_url=row.recording_url,
        expires_at=row.expires_at,
    )
