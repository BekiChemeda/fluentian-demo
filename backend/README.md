# Fluentian Backend

Production-ready FastAPI backend for Fluentian MVP.

## Features
- JWT auth (access + refresh)
- Async SQLAlchemy + PostgreSQL
- Lessons, progress, streak, and XP tracking
- Basic community matching and chat send endpoint
- Structured error responses
- Pagination on lesson list

## Run
1. Create and activate virtual env.
2. Install dependencies:
   pip install -r requirements.txt
3. Copy env file:
   cp .env.example .env
4. Configure Gemini in `.env` for AI coach chat:
   - `GEMINI_API_KEY=<your_key>`
   - `GEMINI_MODEL=gemini-3-flash-preview`
5. Start API:
   uvicorn app.main:app --reload
6. Seed lessons:
   python seed_lessons.py

## Migrations
Use Alembic for schema evolution across environments:
1. Create migration:
   alembic revision --autogenerate -m "describe change"
2. Apply migration:
   alembic upgrade head
3. Roll back one step if needed:
   alembic downgrade -1

## API
- POST /auth/register
- POST /auth/login
- POST /auth/refresh
- GET /user/me
- GET /lessons?page=1&page_size=10
- GET /lessons/{id}
- POST /lessons/{id}/complete
- GET /progress
- GET /match
- POST /chat/send
