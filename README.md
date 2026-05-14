# Seed OS Manager

## Purpose

Seed OS Manager is a tiny signed macOS helper that becomes the durable
[TCC](https://eclecticlight.co/2024/02/29/explainer-tcc/) principal for any
SEED-driven Apple Event. Grant it Automation access to Messages, Calendar,
or any other app *once*, and every SEED that needs that target works
silently from then on. No more `sshd-keygen-wrapper wants to control
Messages` over SSH.

The on-disk surface is exactly two things:

- `/Applications/Seed OS Manager.app` — the signed, notarized .app bundle
  that holds the TCC grants.
- `/usr/local/bin/seedctl` — a symlink into the bundle's CLI entry point.

The CLI exposes a single verb, `seedctl osa`, which executes a user-supplied
AppleScript. SEEDs supply the script.

## Install

Tell any AI agent:

> Install `https://github.com/plow-pbc/seed-os-manager`

## License

MIT
