#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
APP="/Applications/Weather.app"
BINARY="$APP/Contents/MacOS/Weather"

echo "▶ Building..."
swift build -c release --package-path "$REPO"

echo "▶ Stopping running instance..."
pkill -x Weather 2>/dev/null || true
sleep 0.5

echo "▶ Installing..."
mkdir -p "$APP/Contents/MacOS"
cp "$REPO/.build/release/Weather" "$BINARY"
cp "$REPO/Info.plist" "$APP/Contents/Info.plist"

echo "▶ Re-signing..."
codesign --remove-signature "$APP"
codesign -s - "$APP"

echo "▶ Launching..."
open "$APP"

echo "✅ Done."
