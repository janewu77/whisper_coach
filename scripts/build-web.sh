#!/bin/sh
# Build the Flutter web app and place it where the backend serves it (/app).
#
# The Docker image does this automatically (see backend/Dockerfile). This script
# is for LOCAL dev, where you run uvicorn directly and want /app to work.
#
#   sh scripts/build-web.sh
#
# Requires the Flutter SDK (>= 3.16, per frontend/pubspec.yaml) on PATH.
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FRONTEND="$ROOT/frontend"
DEST="$ROOT/backend/app/static/app"

cd "$FRONTEND"
flutter pub get

# Auth0 config is compiled into the bundle. Export these before running, e.g.
#   export AUTH0_DOMAIN=your-tenant.eu.auth0.com
#   export AUTH0_CLIENT_ID=xxxx
#   export AUTH0_AUDIENCE=https://whisper-coach.dacheng.dev/api
# If unset, the app builds with LOGIN DISABLED (no start/login page appears).
if [ -z "$AUTH0_DOMAIN" ] || [ -z "$AUTH0_CLIENT_ID" ]; then
  echo "[build-web] WARNING: AUTH0_DOMAIN/AUTH0_CLIENT_ID not set — building with login DISABLED." >&2
fi

flutter build web --release --base-href /app/ \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://whisper-coach.dacheng.dev}" \
  --dart-define=AUTH0_DOMAIN="${AUTH0_DOMAIN:-}" \
  --dart-define=AUTH0_CLIENT_ID="${AUTH0_CLIENT_ID:-}" \
  --dart-define=AUTH0_AUDIENCE="${AUTH0_AUDIENCE:-}"

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$FRONTEND/build/web/." "$DEST/"
echo "[build-web] Flutter web -> $DEST"
