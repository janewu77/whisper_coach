#!/bin/sh
# Copy the pitch deck from docs/ into the backend's served static assets.
#
# Why: Coolify builds the backend with build context = /backend, so the
# Dockerfile cannot reach ../docs. This script copies the deck into the backend
# so it ships in the image and is served at /pitch-deck.pdf.
#
# Run it before each deploy (locally, or as a Coolify pre-deployment command):
#   sh scripts/sync-deck.sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/docs/AI_Football_Coach_Pitch_Deck.pdf"
DEST="$ROOT/backend/app/static/pitch-deck.pdf"

if [ ! -f "$SRC" ]; then
  echo "[sync-deck] source not found: $SRC" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"
cp "$SRC" "$DEST"
echo "[sync-deck] copied deck -> $DEST"
