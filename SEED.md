# Purpose

> See [README#Purpose](README.md#purpose).

## Normative Language

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT,
RECOMMENDED, MAY, and OPTIONAL in this document are to be interpreted as
described in RFC 2119.

## Dependencies

- A Mac running macOS ≥13.0 (Ventura). Authored on macOS 26.4.1 / arm64.
- ≥20 MB free disk (~10 MB .dmg in `$TMPDIR`, ~10 MB extracted bundle).
- System tools at `/usr/bin/*`: `curl`, `hdiutil`, `open`, `pgrep`, `pkill`,
  `ln`. No install needed.
- `~/.local/bin` for the `seedctl` symlink — user-writable (often, but not
  guaranteed to be, on `PATH`); the install block creates it if absent and
  invokes the symlink by absolute path, so nothing here depends on `PATH`. No
  `sudo`, ever.

Run the following block to install Seed OS Manager. The block is idempotent:
re-running re-downloads the current artifact, replaces the installed bundle,
and refreshes the symlink.

```bash
set -euo pipefail

DMG="$TMPDIR/SeedOSManager.dmg"
APP="/Applications/Seed OS Manager.app"
LINK="$HOME/.local/bin/seedctl"
BIN_REL="Contents/MacOS/seedctl"

# Bundle-identity verification helper. This SEED is the OWNER of the
# co.plow.seed-os-manager / Team ID 3559PD337Z signing identity, so the
# trust contract for that bundle lives here. codesign --verify proves the
# signature is intact; spctl --assess proves macOS accepts the bundle as
# notarized; the Identifier + TeamIdentifier grep proves the freshly-mounted
# bundle is *this product*, not some other Apple-signed app shaped like
# Seed OS Manager.app. Fails loudly on any mismatch.
verify_bundle_identity() {
  local bundle="$1" want_id="$2" want_team="$3"
  codesign --verify --deep --strict --verbose=0 "$bundle" \
    || { echo "$bundle: codesign verify failed" >&2; exit 1; }
  spctl --assess --type execute "$bundle" \
    || { echo "$bundle: Gatekeeper/notarization assessment failed" >&2; exit 1; }
  local meta
  meta=$(codesign -d --verbose=2 "$bundle" 2>&1)
  echo "$meta" | grep -qxF "Identifier=$want_id" \
    || { echo "$bundle: Identifier mismatch (expected $want_id)" >&2; exit 1; }
  echo "$meta" | grep -qxF "TeamIdentifier=$want_team" \
    || { echo "$bundle: TeamIdentifier mismatch (expected $want_team)" >&2; exit 1; }
}

# 1. Download the latest production .dmg.
curl -fSL --retry 3 -o "$DMG" https://plow.co/download/seed-os-manager

# 2. SIGTERM a running Seed OS Manager so the copy doesn't race the binary.
#    pkill (not osascript) — we are NOT using the very thing we're installing.
if pgrep -x seedctl >/dev/null; then
  pkill -x seedctl || true
  for _ in 1 2 3 4 5; do pgrep -x seedctl >/dev/null || break; sleep 1; done
fi

# 3. Mount the .dmg; capture the assigned /Volumes/<name> path.
MOUNT_POINT=$(hdiutil attach -nobrowse -readonly "$DMG" \
  | awk -F'\t' '/^\/dev\// && $NF ~ /^\/Volumes\// {print $NF; exit}')
[ -n "$MOUNT_POINT" ] || { echo "could not detect mount point" >&2; exit 1; }

# 4. Verify the freshly-mounted bundle's signature, notarization, and EXACT
#    identity before copying it into /Applications.
verify_bundle_identity "$MOUNT_POINT/Seed OS Manager.app" "co.plow.seed-os-manager" "3559PD337Z"

# 5. Replace /Applications/Seed OS Manager.app. ditto (not cp -R): BSD cp -R
#    nests source-into-existing-dest, so a re-run could produce
#    /Applications/Seed OS Manager.app/Seed OS Manager.app. The rm -rf above
#    keeps the happy path clean; ditto removes the nesting hazard entirely.
rm -rf "$APP"
ditto "$MOUNT_POINT/Seed OS Manager.app" "$APP"

# 6. Eject.
hdiutil detach "$MOUNT_POINT"

# 7. Place the seedctl symlink in ~/.local/bin — user-owned, so the install
#    never needs sudo. mkdir -p creates the dir on a Mac that doesn't have
#    it yet.
TARGET="$APP/$BIN_REL"
mkdir -p "$(dirname "$LINK")"
ln -sfn "$TARGET" "$LINK"

# 8. Smoke test (no TCC-protected target — pure arithmetic, won't prompt).
#    Invoke "$LINK" by absolute path, not bare `seedctl`: this shell may not
#    have ~/.local/bin on PATH yet, and a stale seedctl earlier on PATH could
#    false-pass against the wrong binary.
test "$("$LINK" osa --stdin <<<'return 1 + 1')" = "2"
```

### Requirements

| kind | label | phase | satisfy | bypass |
|---|---|---|---|---|
| hardware | Mac running macOS ≥13.0 | preflight | this machine | |
| system | ≥20 MB free disk (~10 MB .dmg + ~10 MB bundle) | preflight | free space on the install volume | |
| auth | macOS Automation grant for the Seed OS Manager TCC principal | in-flow | Allow at the first-use Automation prompt | grant already present from an earlier install or out-of-band approval (System Settings → Privacy & Security → Automation) |

## Objects

### Seed OS Manager.app

- The installed application bundle at `/Applications/Seed OS Manager.app`.
- Bundle identifier `co.plow.seed-os-manager`. This identifier is the
  durable TCC principal under which all Apple Events from `seedctl` are
  attributed. The presence and launchability of this bundle is the SEED's
  single source of truth for "Seed OS Manager is installed."

### seedctl

- The CLI entry point at `~/.local/bin/seedctl` (a symlink into the
  .app's `Contents/MacOS/seedctl`). One static binary serves both CLI
  mode (when `argv[0]` resolves to `seedctl`) and .app mode (when launched
  by launchd via `open -a`).

### TCC grants

- Per-target Automation grants under the Seed OS Manager principal in
  System Settings → Privacy & Security → Automation. NOT installed by
  this SEED; accumulated lazily on first use of each target.

## Actions

### Seed OS Manager.app is replaced

- The install action MUST `pkill -x seedctl` before the bundle copy, then
  wait up to 5s for the process to exit.
- Before copying the freshly-mounted bundle into `/Applications`, the install
  action MUST verify its signature, notarization, and EXACT identity via
  `verify_bundle_identity "$MOUNT_POINT/Seed OS Manager.app"
  co.plow.seed-os-manager 3559PD337Z` (i.e. `codesign --verify --deep
  --strict`, `spctl --assess --type execute`, and an exact match on
  `Identifier=co.plow.seed-os-manager` + `TeamIdentifier=3559PD337Z`),
  failing loudly on any mismatch. This SEED owns that signing identity, so
  the trust contract lives here.
- The install action MUST `rm -rf "$APP"` then copy with `ditto`, not
  `cp -R`: BSD `cp -R src/Seed OS Manager.app /Applications/` nests
  source-into-existing-dest, producing
  `/Applications/Seed OS Manager.app/Seed OS Manager.app` when the
  destination already exists. The `rm -rf` keeps the happy path clean;
  `ditto` removes the nesting hazard entirely.
- The install action MUST NOT use `osascript -e 'tell application "Seed
  OS Manager" to quit'`. Self-bootstrap MUST NOT depend on the very
  TCC-gated Apple Events surface this SEED exists to enable.

### seedctl symlink is placed

- The install action MUST `mkdir -p ~/.local/bin` and place the symlink there
  with `ln -sfn`. `~/.local/bin` is user-owned, so the symlink never needs
  `sudo` — the install stays fully autonomous. (Downstream SEEDs invoke
  `seedctl` by its absolute bundle path regardless, and the install/smoke
  probes invoke the symlink by its absolute path too, so the symlink is a
  PATH-independent CLI convenience, not a load-bearing dependency.)

### AppleScript is executed

- `seedctl osa <script>` (or `--file` / `--stdin`) writes the script and
  metadata to a per-call tempdir, invokes `open -W -a "Seed OS Manager"
  --args osa --req <dir>`, blocks until the .app exits, then prints the
  captured stdout/stderr and exits with the AppleScript's exit code.
- The .app MUST execute scripts via NSAppleScript in its own process;
  this is what causes TCC to attribute Apple Events to bundle ID
  `co.plow.seed-os-manager` rather than to the caller's responsible-process
  chain.

### TCC grants are accumulated

- The first time `seedctl osa` runs a script that targets a TCC-protected
  app, macOS displays a one-time Automation prompt attributed to "Seed
  OS Manager". On Allow, the grant is durable across reboots and SEED
  installs. On Don't Allow, the script returns exit code 1 with stderr
  "Not authorized to send Apple events to <App>."
- If a grant for the target already exists under the
  `co.plow.seed-os-manager` principal (durable from an earlier install, or
  made out-of-band in System Settings → Privacy & Security → Automation),
  no prompt appears: the call MUST succeed silently. A pre-existing grant
  is an expected success state; install and verification MUST NOT fork or
  abort on it.
- This SEED does NOT pre-prompt for any TCC grant. Priming is intentionally
  deferred to first use (see [eager TCC priming](#eager-tcc-priming)).

## Verification

1. **App bundle present.** Does `/Applications/Seed OS Manager.app`
   exist as a directory containing `Contents/MacOS/seedctl`? Expected: yes.
2. **Bundle ID is the expected TCC principal.** Does
   `defaults read "/Applications/Seed OS Manager.app/Contents/Info"
   CFBundleIdentifier` print exactly `co.plow.seed-os-manager`? Expected: yes.
3. **CLI symlink resolves.** Does `readlink "$HOME/.local/bin/seedctl"`
   print a path ending in `/Seed OS Manager.app/Contents/MacOS/seedctl`,
   and does the resolved target exist and have the executable bit?
   Expected: yes.
4. **AppleScript executes end-to-end.** Does
   `"$HOME/.local/bin/seedctl" osa --stdin <<<'return 1 + 1'` exit 0 and
   print `2` (invoked by absolute path, not bare `seedctl`, so the probe
   never depends on ambient `PATH`)? This
   script touches no TCC-protected target, so it MUST succeed without
   triggering any permission prompt. If this step prompts, something is
   misconfigured upstream of TCC.

## Feedback

(default)

## Open Items

#### Eager TCC priming

No proactive TCC prime; first-use prompts each surface mid-flight in
whatever downstream SEED first reaches for them. Eager-prime alternative
documented for v2 if user pain warrants it.

#### Per-data-class privacy entitlements

No per-data-class privacy entitlements (`NSRemindersUsageDescription`,
`NSCalendarsUsageDescription`, `NSContactsUsageDescription`,
`NSPhotoLibraryUsageDescription`, etc.) in v1. Apple Events to those
per-data-class targets return `errAEEventNotPermitted` without a TCC
prompt. Plain Automation targets (System Events, Music, Mail, Finder,
most other scriptable apps) work normally. SEEDs that need per-data
classes can either route via System Events where possible or wait for
v2 which adds the per-class declarations.
- No universal-binary assertion; authored on arm64. Intel-Mac installs
  unverified.
- No SHA / signature pin on the downloaded `.dmg`. The agent trusts
  plow.co's TLS chain plus macOS's notarization gate at first launch.
- No uninstall action. To remove: `rm -rf "/Applications/Seed OS Manager.app"
  ~/.local/bin/seedctl` and revoke grants under System Settings →
  Privacy & Security → Automation.

## Non-Goals

- No Linux or Windows. macOS-only by definition (TCC is the whole point).
- No domain-specific verbs (`message`, `notify`, `quit`, etc.). The single
  `osa` verb is the entire surface; SEEDs supply the AppleScript.
- No long-lived daemon, LaunchAgent, or XPC service in v1.
- No programmatic TCC management (granting, revoking, querying). Apple
  does not expose stable APIs for this from userspace.
- No Accessibility / UI scripting via System Events in v1. SEEDs that
  need this should request it explicitly in a v2 issue.
