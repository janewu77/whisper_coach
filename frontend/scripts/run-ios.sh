#!/bin/sh
# Run the app (debug) with the Auth0 + API config compiled in via --dart-define.
#
# Usage:
#   sh scripts/run-ios.sh                 # pick a device interactively
#   sh scripts/run-ios.sh -d <device-id>  # e.g. an iPhone simulator id
#
# Override any value via the environment, e.g.
#   API_BASE_URL=http://localhost:8000 sh scripts/run-ios.sh -d <id>
#
# The CLIENT_ID/DOMAIN/AUDIENCE below are the public Auth0 SPA identifiers
# (safe to commit — they are not secrets). For native login to complete, the
# Auth0 app's Allowed Callback/Logout URLs must include:
#   com.example.whisperCoach://whisper-coach.eu.auth0.com/ios/com.example.whisperCoach/callback
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Use fvm's Flutter if available (the repo pins a version), else plain flutter.
FLUTTER="flutter"
if command -v fvm >/dev/null 2>&1; then
  FLUTTER="fvm flutter"
fi

exec $FLUTTER run "$@" \
  --dart-define=API_BASE_URL="${API_BASE_URL:-https://whisper-coach.dacheng.dev}" \
  --dart-define=AUTH0_DOMAIN="${AUTH0_DOMAIN:-whisper-coach.eu.auth0.com}" \
  --dart-define=AUTH0_CLIENT_ID="${AUTH0_CLIENT_ID:-9kQ9HvV7ZUaqJzISwzeNs2VwxiIvzzJm}" \
  --dart-define=AUTH0_AUDIENCE="${AUTH0_AUDIENCE:-https://whisper-coach.dacheng.dev/api}"
