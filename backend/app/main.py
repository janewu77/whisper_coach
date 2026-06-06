from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from app.config import settings
from app.routers import matches, roster

STATIC_DIR = Path(__file__).parent / "static"

app = FastAPI(title="Whisper Coach API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(roster.router)
app.include_router(matches.router)


@app.get("/", include_in_schema=False)
def landing():
    """Serve the project presentation page as the start page."""
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/health", tags=["health"])
def health():
    return {"status": "ok"}
