from fastapi import FastAPI

from api.router import router
from config.settings import settings
from core.logging import configure_logging
from api.documents import router as documents_router

configure_logging()

app = FastAPI(
    title=settings.app_name,
    description="AI-powered research assistant",
    version=settings.app_version,
)

app.include_router(router)
app.include_router(documents_router)