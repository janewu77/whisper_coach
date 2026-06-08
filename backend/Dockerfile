# Whisper Coach backend image.
#
# Build context is the REPO ROOT (not backend/) so the build can compile the
# Flutter web app from frontend/ and copy the pitch deck from docs/.
#   Local:   docker build -f backend/Dockerfile -t whisper-coach-backend .
#   Coolify: Base Directory = /, Dockerfile Location = backend/Dockerfile

# --- Stage 1: build the Flutter web app ---
FROM ghcr.io/cirruslabs/flutter:stable AS webbuild
WORKDIR /build
# Resolve deps first for layer caching.
COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get
# Then the rest of the app and build. base-href must match the serve path (/app/).
COPY frontend ./
# Auth0 config is compiled into the web bundle via --dart-define. Provide these
# as build args (in Coolify: Build Variables) so the deployed app sends tokens;
# leave them blank to build with login disabled. They must match the backend's
# AUTH0_DOMAIN / AUTH0_AUDIENCE.
ARG AUTH0_DOMAIN=""
ARG AUTH0_CLIENT_ID=""
ARG AUTH0_AUDIENCE=""
ARG API_BASE_URL="https://whisper-coach.dacheng.dev"
RUN flutter build web --release --base-href /app/ \
    --dart-define=API_BASE_URL="$API_BASE_URL" \
    --dart-define=AUTH0_DOMAIN="$AUTH0_DOMAIN" \
    --dart-define=AUTH0_CLIENT_ID="$AUTH0_CLIENT_ID" \
    --dart-define=AUTH0_AUDIENCE="$AUTH0_AUDIENCE"

# --- Stage 2: Python runtime ---
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

# Pitch deck: copied straight from docs/ at build time (served at /pitch-deck.pdf).
COPY docs/AI_Football_Coach_Pitch_Deck.pdf ./app/static/pitch-deck.pdf

# Flutter web build output: served at /app.
COPY --from=webbuild /build/build/web ./app/static/app

EXPOSE 8000

# Entrypoint runs migrations (unless RUN_MIGRATIONS=false) then execs the CMD.
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
