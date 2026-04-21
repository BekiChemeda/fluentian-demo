from pydantic import BaseModel


class ProgressItem(BaseModel):
    lesson_id: int
    completed: bool
    score: int


class ProgressResponse(BaseModel):
    items: list[ProgressItem]
