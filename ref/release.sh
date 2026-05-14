#!/usr/bin/env bash
# Production release: bundle, codesign with Developer ID, notarize, staple,
# and produce a distributable DMG.

set -euo pipefail

: "${TEAMID:?must set TEAMID env var, e.g. ABCDE12345}"
: "${NOTARY_PROFILE:=plow-notary}"

cd "$(dirname "$0")/.."
"$PWD/ref/bundle.sh"

APP="dist/Seed OS Manager.app"
DMG="dist/SeedOSManager.dmg"

echo "=> codesign with Developer ID"
codesign --force --options runtime \
  --entitlements ref/SeedOSManager.entitlements \
  --sign "Developer ID Application: The Plow Collective, Inc ($TEAMID)" \
  --timestamp \
  "$APP"

# Verify the signature is well-formed and accepted by Gatekeeper.
codesign --verify --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP" || true   # may report
                                                            # "rejected" until notarized — fine

echo "=> create DMG"
rm -f "$DMG"
hdiutil create -volname "Seed OS Manager" \
  -srcfolder "$APP" \
  -ov -format UDZO \
  "$DMG"

echo "=> notarize"
xcrun notarytool submit "$DMG" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "=> staple"
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

echo "ok: $DMG ready for distribution"
ls -la "$DMG"
