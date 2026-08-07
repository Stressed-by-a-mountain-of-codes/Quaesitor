from fastapi import FastAPI

from api.router import router

app = FastAPI(title="Quaesitor")

app.include_router(router)