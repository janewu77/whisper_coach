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
flutter build web --release --base-href /app/

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$FRONTEND/build/web/." "$DEST/"
echo "[build-web] Flutter web -> $DEST"
