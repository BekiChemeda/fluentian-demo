from pydantic import BaseModel


class BadgeResponse(BaseModel):
    id: int
    name: str
    description: str
    unlocked: bool
    unlock_date: str | None
    unlock_criteria: str
    icon_svg: str


class BadgeListResponse(BaseModel):
    items: list[BadgeResponse]
