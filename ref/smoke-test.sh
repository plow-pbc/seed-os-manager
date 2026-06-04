#!/usr/bin/env bash
# End-to-end smoke test. Bundles seedctl, ad-hoc signs it (so /usr/bin/open
# can launch it on this machine without notarization), places the bundle
# under /Applications, places a /usr/local/bin symlink, and runs the
# arithmetic-only AppleScript. No TCC prompts will be involved because
# the script touches no other app.

set -euo pipefail

cd "$(dirname "$0")/.."
"$PWD/ref/bundle.sh"

APP="/Applications/Seed OS Manager.app"
LINK="/usr/local/bin/seedctl"
SRC="$PWD/dist/Seed OS Manager.app"
BIN_REL="Contents/MacOS/seedctl"

# Ad-hoc sign (no Developer ID needed for local test). Required because
# unsigned binaries from `cp` would be killed by macOS at launch.
echo "=> ad-hoc codesign"
codesign --force --deep --sign - "$SRC"

echo "=> install to /Applications"
# ditto (not cp -R): BSD cp -R nests source-into-existing-dest, so a re-run
# could produce /Applications/Seed OS Manager.app/Seed OS Manager.app. The
# rm -rf keeps the happy path clean; ditto removes the nesting hazard. Mirrors
# the canonical install block in SEED.md.
rm -rf "$APP"
ditto "$SRC" "$APP"

echo "=> place /usr/local/bin/seedctl symlink"
TARGET="$APP/$BIN_REL"
if ln -sfn "$TARGET" "$LINK" 2>/dev/null; then
  :
else
  echo "   sudo required for $LINK"
  sudo ln -sfn "$TARGET" "$LINK"
fi

echo "=> run smoke test"
result=$(seedctl osa --stdin <<<'return 1 + 1')
test "$result" = "2" || { echo "FAIL: expected 2, got '$result'"; exit 1; }

echo "ok: smoke test passed"
