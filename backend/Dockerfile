# Whisper Coach backend image.
#
# Build context is the REPO ROOT (not backend/) so the build can copy the pitch
# deck from docs/ into the served assets automatically on every deploy.
#   Local:   docker build -f backend/Dockerfile -t whisper-coach-backend .
#   Coolify: Base Directory = /, Dockerfile Location = backend/Dockerfile
FROM python:3.12-slim

# uv for fast, locked installs.
COPY --from=ghcr.io/astral-sh/uv:0.8 /uv /uvx /bin/

ENV PYTHONUNBUFFERED=1 \
    UV_LINK_MODE=copy \
    UV_COMPILE_BYTECODE=1 \
    PATH="/app/.venv/bin:$PATH"

WORKDIR /app

# Install runtime deps first (cached layer; no dev group, no project source yet).
COPY backend/pyproject.toml backend/uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Application source + migrations.
COPY backend/app ./app
COPY backend/alembic ./alembic
COPY backend/alembic.ini ./
COPY backend/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Pitch deck: copied straight from docs/ at build time, so the deployed deck is
# always whatever is committed in docs/ — no manual sync step needed.
COPY docs/AI_Football_Coach_Pitch_Deck.pdf ./app/static/pitch-deck.pdf

EXPOSE 8000

# Entrypoint runs migrations (unless RUN_MIGRATIONS=false) then execs the CMD.
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
