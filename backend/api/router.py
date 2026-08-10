from fastapi import APIRouter
import logging
from config.settings import settings

router = APIRouter()
logger = logging.getLogger("quaesitor")

@router.get("/")
def root() -> dict[str, str]:
    return {
        "project": "Quaesitor",
        "version": settings.app_version,
        "status": "running",
        "docs": "/docs",
    }


@router.get("/health")
def health_check() -> dict[str, str]:
    logger.info("Health check requested")
    return {
        "status": "ok",
    }