<h1 align="center">Captr 📸</h1>

<p align="center">
  <b>A free, open-source screenshot &amp; annotation app for macOS.</b><br>
  Everything <a href="https://xnipapp.com/">Xnip</a> does — plus recording, GIF, and OCR —
  built from scratch, 100% local, no subscription.
</p>

<p align="center">
  <a href="#license"><img alt="License: MIT OR Apache-2.0" src="https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg"></a>
  <img alt="Platform: macOS 13+" src="https://img.shields.io/badge/macOS-13%2B-lightgrey.svg">
  <img alt="Language: Objective-C" src="https://img.shields.io/badge/lang-Objective--C-orange.svg">
</p>

---

Captr lives in your menu bar. Hit a hotkey, grab a region, window, or the whole
screen, then annotate, pin, or share it — all on your Mac, with **no network
access** whatsoever.

## Features

**Capture** *(v0.1 — available now)*
- 🎯 **Region capture** — drag a selection with a live `W × H` readout
- 🪟 **Window capture** — hover to highlight, click to grab (with shadow)
- 🖥 **Full-screen capture**
- ⌨️ **Global hotkeys** — `⌃⇧⌘A` region · `⌃⇧⌘W` window · `⌃⇧⌘F` full screen
- ⚙️ **Settings window** — rebind every capture shortcut to your own keys, pick the
  save folder/format, and toggle copy/save/editor/sound (Settings… or `⌘,`)
- 💾 **Save** as PNG/JPG with macOS-style timestamped names, and 📋 **copy** to clipboard
- 🔒 **100% local** — no servers, no telemetry, no account

**Annotation editor** *(v0.2 — available now)*
- 🖊 Tools: **arrow, line, rectangle, ellipse, pen, highlighter, text, step numbers**
- 🌫 **Blur, pixelate, and redact** regions to hide sensitive content
- 🎯 **Select** tool to move, delete, and restyle annotations
- ↩️ Full **undo/redo**, color + thickness pickers
- 📋 **Copy** or 💾 **Save** the flattened result at full capture resolution

**Coming next** *(see [`docs/ROADMAP.md`](docs/ROADMAP.md))*
- 📌 Pin screenshots as always-on-top floating windows
- ✂️ Crop while annotating; drag-resize handles
- 🎨 Color picker + 📏 screen ruler / pixel measure
- 📜 Scrolling capture (full-page, auto-scroll + stitch)
- 🎥 Screen recording → MP4/GIF · 🔤 OCR text extraction
- 🖼 Backgrounds, shadows & frames for share-ready images

## Build from source

Requires the Xcode **Command Line Tools** (`xcode-select --install`). Full
Xcode is *not* required.

```sh
git clone https://github.com/millwrights/captr.git
cd captr
make run        # builds build/Captr.app and launches it
```

On first launch, grant **Screen Recording** permission under
**System Settings → Privacy & Security → Screen Recording**, then quit and
`make run` again.

Other targets:

```sh
make            # build build/Captr.app
make run        # build + launch from build/
make install    # build + install into /Applications and launch it there
make test       # run unit tests
make clean      # remove build/
```

### Making permissions persist across rebuilds

macOS ties Screen Recording permission to the app's code signature. An unsigned
app changes identity every rebuild, so the grant stops applying. Create a stable
local signing identity once (reusable across all your projects):

```sh
./scripts/dev-cert.sh          # creates a "Millwrights" identity (pass a name to override)
echo "Millwrights" > .signing-identity
make run
```

## Install with Homebrew

See [`docs/HOMEBREW.md`](docs/HOMEBREW.md).

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). Issues and PRs welcome.

## License

Captr is dual-licensed under either of

- MIT license ([LICENSE-MIT](LICENSE-MIT))
- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE))

at your option. It is an independent, clean-room implementation and contains no
source code from Xnip, CleanShot X, Shottr, or any other project.
