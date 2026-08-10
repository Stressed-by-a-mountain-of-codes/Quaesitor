from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
    )

    app_name: str = "Quaesitor"
    app_version: str = "0.1.0"

    app_env: str = "development"
    debug: bool = True

    log_level: str = "INFO"


settings = Settings()