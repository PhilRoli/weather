#!/bin/bash
set -e

APP_NAME="Weather"
BUNDLE="$APP_NAME.app"
BINARY_NAME="Weather"
BUILD_DIR=".build/release"

echo "▶ Building..."
swift build -c release

echo "▶ Creating bundle..."
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"

cp "$BUILD_DIR/$BINARY_NAME" "$BUNDLE/Contents/MacOS/$BINARY_NAME"
cp Info.plist "$BUNDLE/Contents/Info.plist"

echo "▶ Signing..."
codesign --force --sign - "$BUNDLE"

echo "✅ $BUNDLE ready"
echo "   To install: cp -r $BUNDLE /Applications/"
