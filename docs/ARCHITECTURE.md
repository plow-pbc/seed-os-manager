# Architecture

The full design is captured in the seed2 repo's design history at
`tmp/2026-05-14-seed-os-manager-design.md`. This file is a short
operator-facing supplement.

## How TCC attribution works

The single Swift binary (`Contents/MacOS/seedctl`) runs in two modes,
distinguished at runtime by `getppid()`:

- `getppid() == 1` (launchd) → **.app mode**. Reads the request files,
  runs `NSAppleScript` in-process, writes `out`/`err`/`exit` files.
- otherwise → **CLI mode**. Writes the script to a per-call tempdir,
  invokes `open -W -a "Seed OS Manager"`, blocks until the .app exits,
  prints the captured output, exits with the script's exit code.

`open -W -a` causes launchd to spawn the .app as a child of launchd.
That breaks the parent-process chain, so TCC attributes Apple Events to
this bundle's identifier (`co.plow.seed-os-manager`), not to whatever
shell or SSH session called the CLI.

## Verified-on-real-hardware notes

- TCC attribution confirmed on macOS 26.4.1 / arm64 (date 2026-05-14):
  a System Events Apple Event prompts for "Seed OS Manager" (bundle ID
  `co.plow.seed-os-manager`), not the calling process. Grant persists
  across CLI invocations and across shell sessions.
- Per-data-class privacy targets (Reminders, Calendar, Contacts,
  Photos) return `errAEEventNotPermitted` without a TCC prompt because
  v1's entitlements only declare Automation. See
  [per-data-class privacy entitlements](../SEED.md#per-data-class-privacy-entitlements)
  for the v2 path.
- The arithmetic-only smoke test (`return 1 + 1`) does not touch any
  TCC-protected target and runs silently — used as the install
  acceptance probe in `## Verify`.
