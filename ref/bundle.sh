#!/usr/bin/env bash
# Builds a universal seedctl binary, wraps it in Seed OS Manager.app, places
# the result under dist/. Does NOT sign or notarize — release.sh does that.

set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"
DIST="$ROOT/dist"
APP="$DIST/Seed OS Manager.app"

rm -rf "$DIST"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

echo "=> swift build (release, universal)"
swift build -c release \
  --arch arm64 --arch x86_64

# Layout the bundle.
cp ".build/apple/Products/Release/seedctl" "$APP/Contents/MacOS/seedctl"
cp "ref/Info.plist"                         "$APP/Contents/Info.plist"
cp "ref/AppIcon.icns"                       "$APP/Contents/Resources/AppIcon.icns"

# Mark the binary executable (cp preserves perms but be defensive).
chmod +x "$APP/Contents/MacOS/seedctl"

echo "=> wrote $APP"
