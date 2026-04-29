from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Fluentian API"
    env: str = "dev"
    database_url: str
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 7
    cors_origins: str = "*"
    log_level: str = "INFO"
    request_id_header: str = "X-Request-ID"
    rate_limit_enabled: bool = True
    rate_limit_requests_per_minute: int = 120
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-3-flash-preview"
    ai_context_turn_limit: int = 12
    redis_url: str = "redis://localhost:6379/0"
    redis_queue_key: str = "fluentian:match:queue"
    redis_presence_prefix: str = "fluentian:presence"
    redis_user_events_prefix: str = "fluentian:events:user"
    redis_session_prefix: str = "fluentian:session"
    redis_session_ttl_seconds: int = 3600
    allow_cross_base_language_matching: bool = True
    matchmaking_loop_enabled: bool = True
    matchmaking_loop_interval_seconds: int = 2
    heartbeat_timeout_seconds: int = 15
    recording_retention_hours: int = 24
    celery_broker_url: str = "redis://localhost:6379/1"
    celery_result_backend: str = "redis://localhost:6379/2"
    fcm_server_key: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", case_sensitive=False, extra="ignore")

    @property
    def cors_origins_list(self) -> List[str]:
        if self.cors_origins.strip() == "*":
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()
