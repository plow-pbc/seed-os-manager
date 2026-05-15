# Purpose

> See [[README#Purpose]].

## Normative Language

The key words MUST, MUST NOT, REQUIRED, SHALL, SHALL NOT, SHOULD, SHOULD NOT,
RECOMMENDED, MAY, and OPTIONAL in this document are to be interpreted as
described in RFC 2119.

## Dependencies

- A Mac running macOS ≥13.0 (Ventura). Authored on macOS 26.4.1 / arm64.
- ≥20 MB free disk (~10 MB .dmg in `$TMPDIR`, ~10 MB extracted bundle).
- System tools at `/usr/bin/*`: `curl`, `hdiutil`, `open`, `pgrep`, `pkill`,
  `ln`. No install needed.
- Write access to `/usr/local/bin/` for the `seedctl` symlink. The install
  block detects ownership and asks before invoking `sudo`.

Run the following block to install Seed OS Manager. The block is idempotent:
re-running re-downloads the current artifact, replaces the installed bundle,
and refreshes the symlink.

```bash
set -euo pipefail

DMG="$TMPDIR/SeedOSManager.dmg"
APP="/Applications/Seed OS Manager.app"
LINK="/usr/local/bin/seedctl"
BIN_REL="Contents/MacOS/seedctl"

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

# 4. Replace /Applications/Seed OS Manager.app.
rm -rf "$APP"
cp -R "$MOUNT_POINT/Seed OS Manager.app" /Applications/

# 5. Eject.
hdiutil detach "$MOUNT_POINT"

# 6. Place /usr/local/bin/seedctl symlink. Try unprivileged first.
TARGET="$APP/$BIN_REL"
if ln -sfn "$TARGET" "$LINK" 2>/dev/null; then
  :  # success, no sudo needed (Homebrew-style ownership)
else
  echo "Symlinking $LINK requires sudo (Apple-default /usr/local/bin perms)."
  sudo ln -sfn "$TARGET" "$LINK"
fi

# 7. Smoke test (no TCC-protected target — pure arithmetic, won't prompt).
test "$(seedctl osa --stdin <<<'return 1 + 1')" = "2"
```

## Objects

### Seed OS Manager.app ^obj-app

- The installed application bundle at `/Applications/Seed OS Manager.app`.
- Bundle identifier `co.plow.seed-os-manager`. This identifier is the
  durable TCC principal under which all Apple Events from `seedctl` are
  attributed. The presence and launchability of this bundle is the SEED's
  single source of truth for "Seed OS Manager is installed."

### seedctl ^obj-cli

- The CLI entry point at `/usr/local/bin/seedctl` (a symlink into the
  .app's `Contents/MacOS/seedctl`). One static binary serves both CLI
  mode (when `argv[0]` resolves to `seedctl`) and .app mode (when launched
  by launchd via `open -a`).

### TCC grants ^obj-tcc

- Per-target Automation grants under the Seed OS Manager principal in
  System Settings → Privacy & Security → Automation. NOT installed by
  this SEED; accumulated lazily on first use of each target.

## Actions

### Seed OS Manager.app is replaced ^act-replace

- The install action MUST `pkill -x seedctl` before `cp -R`, then wait
  up to 5s for the process to exit.
- The install action MUST NOT use `osascript -e 'tell application "Seed
  OS Manager" to quit'`. Self-bootstrap MUST NOT depend on the very
  TCC-gated Apple Events surface this SEED exists to enable.

### seedctl symlink is placed ^act-link

- The install action MUST attempt unprivileged `ln -sfn` first; on EPERM
  the action MUST display the `sudo` command in full and obtain user
  confirmation before re-running with `sudo`. (The SEED convention's
  per-block trust gate already requires this for any shell block; the
  `sudo` path is just one such block.)

### AppleScript is executed ^act-osa

- `seedctl osa <script>` (or `--file` / `--stdin`) writes the script and
  metadata to a per-call tempdir, invokes `open -W -a "Seed OS Manager"
  --args osa --req <dir>`, blocks until the .app exits, then prints the
  captured stdout/stderr and exits with the AppleScript's exit code.
- The .app MUST execute scripts via NSAppleScript in its own process;
  this is what causes TCC to attribute Apple Events to bundle ID
  `co.plow.seed-os-manager` rather than to the caller's responsible-process
  chain.

### TCC grants are accumulated ^act-tcc-grant

- The first time `seedctl osa` runs a script that targets a TCC-protected
  app, macOS displays a one-time Automation prompt attributed to "Seed
  OS Manager". On Allow, the grant is durable across reboots and SEED
  installs. On Don't Allow, the script returns exit code 1 with stderr
  "Not authorized to send Apple events to <App>."
- This SEED does NOT pre-prompt for any TCC grant. Priming is intentionally
  deferred to first use (see [[#^o-eager]]).

## Verify

1. **App bundle present.** ^v-bundle Does `/Applications/Seed OS Manager.app`
   exist as a directory containing `Contents/MacOS/seedctl`? Expected: yes.
2. **Bundle ID is the expected TCC principal.** ^v-id Does
   `defaults read "/Applications/Seed OS Manager.app/Contents/Info"
   CFBundleIdentifier` print exactly `co.plow.seed-os-manager`? Expected: yes.
3. **CLI symlink resolves.** ^v-link Does `readlink /usr/local/bin/seedctl`
   print a path ending in `/Seed OS Manager.app/Contents/MacOS/seedctl`,
   and does the resolved target exist and have the executable bit?
   Expected: yes.
4. **AppleScript executes end-to-end.** ^v-smoke Does
   `seedctl osa --stdin <<<'return 1 + 1'` exit 0 and print `2`? This
   script touches no TCC-protected target, so it MUST succeed without
   triggering any permission prompt. If this step prompts, something is
   misconfigured upstream of TCC.

## Feedback

(default)

## Open

- No proactive TCC prime; first-use prompts each surface mid-flight in
  whatever downstream SEED first reaches for them. Eager-prime alternative
  documented for v2 if user pain warrants it. ^o-eager
- No per-data-class privacy entitlements (`NSRemindersUsageDescription`,
  `NSCalendarsUsageDescription`, `NSContactsUsageDescription`,
  `NSPhotoLibraryUsageDescription`, etc.) in v1. Apple Events to those
  per-data-class targets return `errAEEventNotPermitted` without a TCC
  prompt. Plain Automation targets (System Events, Music, Mail, Finder,
  most other scriptable apps) work normally. SEEDs that need per-data
  classes can either route via System Events where possible or wait for
  v2 which adds the per-class declarations. ^o-perdata
- No universal-binary assertion; authored on arm64. Intel-Mac installs
  unverified. ^o-universal
- No SHA / signature pin on the downloaded `.dmg`. The agent trusts
  plow.co's TLS chain plus macOS's notarization gate at first launch. ^o-pin
- No uninstall action. To remove: `rm -rf "/Applications/Seed OS Manager.app"
  /usr/local/bin/seedctl` and revoke grants under System Settings →
  Privacy & Security → Automation. ^o-uninstall

## Non-Goals

- No Linux or Windows. macOS-only by definition (TCC is the whole point).
- No domain-specific verbs (`message`, `notify`, `quit`, etc.). The single
  `osa` verb is the entire surface; SEEDs supply the AppleScript.
- No long-lived daemon, LaunchAgent, or XPC service in v1.
- No programmatic TCC management (granting, revoking, querying). Apple
  does not expose stable APIs for this from userspace.
- No Accessibility / UI scripting via System Events in v1. SEEDs that
  need this should request it explicitly in a v2 issue.
