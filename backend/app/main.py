import logging
import os
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.routers import imports, matches, me, roster

STATIC_DIR = Path(__file__).parent / "static"
FLUTTER_DIR = STATIC_DIR / "app"
_BACKEND_DIR = Path(__file__).parent.parent  # contains alembic.ini + alembic/

log = logging.getLogger("whisper_coach")


def _run_migrations() -> None:
    """Apply Alembic migrations to head. A safety net so the schema is current
    however the container is started (some platforms bypass the Docker
    entrypoint). Disable with AUTO_MIGRATE=false."""
    from alembic import command
    from alembic.config import Config as AlembicConfig

    cfg = AlembicConfig(str(_BACKEND_DIR / "alembic.ini"))
    cfg.set_main_option("script_location", str(_BACKEND_DIR / "alembic"))
    command.upgrade(cfg, "head")


@asynccontextmanager
async def lifespan(app: FastAPI):
    if os.getenv("AUTO_MIGRATE", "true").lower() != "false":
        try:
            _run_migrations()
            log.info("migrations applied (head)")
        except Exception:  # noqa: BLE001 — log but still start serving
            log.exception("startup migration failed")
    yield


app = FastAPI(title="Whisper Coach API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(me.router)
app.include_router(roster.router)
app.include_router(matches.router)
app.include_router(imports.router)


@app.get("/", include_in_schema=False)
def landing():
    """Serve the project presentation page as the start page."""
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/pitch-deck.pdf", include_in_schema=False)
def pitch_deck():
    """Serve the pitch deck.

    In the deployed image the deck is baked in from docs/ at build time. Locally
    it is created by `scripts/sync-deck.sh`; if absent, return 404.
    """
    deck = STATIC_DIR / "pitch-deck.pdf"
    if not deck.exists():
        raise HTTPException(status_code=404, detail="pitch deck not available")
    return FileResponse(
        deck,
        media_type="application/pdf",
        filename="Whisper-Coach-Pitch-Deck.pdf",
    )


@app.get("/api/health", tags=["health"])
def health():
    return {"status": "ok"}


# Landing-page images + screenshots.
IMG_DIR = STATIC_DIR / "img"
if IMG_DIR.exists():
    app.mount("/img", StaticFiles(directory=IMG_DIR), name="img")

SHOTS_DIR = STATIC_DIR / "shots"
if SHOTS_DIR.exists():
    app.mount("/shots", StaticFiles(directory=SHOTS_DIR), name="shots")

# Flutter web app, served at /app (built into the image; see scripts/build-web.sh
# for local dev). Mounted last so it never shadows the API or root routes.
# html=True serves index.html for /app/ and nested paths.
if FLUTTER_DIR.exists():
    app.mount("/app", StaticFiles(directory=FLUTTER_DIR, html=True), name="flutter")
