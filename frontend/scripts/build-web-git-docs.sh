#!/bin/sh
# 将fluttert的web版发布到github pages/app 目录下
#
#   sh scripts/build-web-git-docs.sh
#
# Requires the Flutter SDK (>= 3.16, per frontend/pubspec.yaml) on PATH.
set -e

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FRONTEND="$ROOT/frontend"
DEST="$ROOT/docs/app"
echo "ROOT: $ROOT"
echo "FRONTEND: $FRONTEND"


cd "$FRONTEND"
flutter pub get
flutter build web --release --base-href /whisper_coach/app/

rm -rf "$DEST"
mkdir -p "$DEST"
cp -R "$FRONTEND/build/web/." "$DEST/"
echo "[build-web] Flutter web -> $DEST"
