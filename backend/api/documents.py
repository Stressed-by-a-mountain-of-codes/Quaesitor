from fastapi import APIRouter

router = APIRouter(prefix="/documents", tags=["Documents"])

@router.get("/")
def list_documents() -> dict[str, list]:
    return {
        "documents": []
    }