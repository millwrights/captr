# Contributing to Captr

Thanks for your interest in Captr! It's a from-scratch, 100% local, open-source
macOS screenshot app. Contributions of all sizes are welcome.

## Ground rules

- **Clean-room only.** Captr contains no code from Xnip, CleanShot X, Shottr, or
  any other app. Take inspiration from *behavior*, never from source. Don't paste
  code you don't have the rights to.
- **macOS-native, no dependencies.** Pure Objective-C + AppKit and Apple system
  frameworks (ScreenCaptureKit, Vision, AVFoundation, …). No third-party
  libraries, no package managers.
- **No network access.** Captr never phones home. Don't add analytics, crash
  reporters, or update checks that hit the network without an explicit opt-in
  discussion first.

## Building

```sh
make          # build build/Captr.app
make run      # build + launch
make test     # run unit tests
```

Requires only the Xcode Command Line Tools (`xcode-select --install`).

## Conventions

- Class prefix **`CP`** (e.g. `CPCaptureEngine`). Bundle id `com.millwrights.captr`.
- ARC everywhere (`-fobjc-arc`). Keep files warning-clean under `-Wall -Wextra`.
- Prefer small, single-purpose classes — one concern per file, mirroring the
  existing `src/` layout.
- Add SPDX headers to new files: `// Captr — SPDX-License-Identifier: MIT OR Apache-2.0`.
- Add a unit test for pure/logic helpers in `tests/CPTests.m` where practical.

## Pull requests

1. Keep PRs focused; reference the roadmap item in `docs/ROADMAP.md` you're
   advancing, and tick it there if you complete it.
2. Make sure `make` and `make test` pass.
3. Describe the user-visible behavior and how you verified it.

By contributing, you agree that your contributions are dual-licensed under
MIT OR Apache-2.0, matching the project license.
