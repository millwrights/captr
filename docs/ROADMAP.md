# Captr Roadmap

Captr is a from-scratch, 100% local, open-source screenshot & annotation app for
macOS. It targets feature parity with **Xnip**, plus the best ideas from
**CleanShot X** (recording, GIF, OCR) and **Shottr** (ruler, pixel measure) —
free, no subscription, and with no network access at all.

Legend: ✅ done · 🚧 partial · ⬜ planned

## v0.1 — Capture core (this milestone)

- ✅ Menu-bar status item with capture actions
- ✅ Global hotkeys (⌃⇧⌘A region · ⌃⇧⌘W window · ⌃⇧⌘F full screen)
- ✅ Region capture with drag selection + live dimensions HUD
- ✅ Window capture with hover-to-highlight + click, includes shadow
- ✅ Full-screen capture
- ✅ Save to disk (PNG/JPG) with macOS-style timestamped names
- ✅ Copy to clipboard
- ✅ Screen Recording permission prompt + stable-signing dev workflow
- 🚧 Multi-display selection (currently primary display only)
- ⬜ Migrate still capture to ScreenCaptureKit `SCScreenshotManager` (macOS 14+) with CG fallback

## v0.2 — Annotation editor

- ✅ Post-capture editor window with a vector canvas (undo/redo)
- ✅ Tools: arrow, line, rectangle, ellipse, freehand pen, text, highlighter
- ✅ Step-number badges (auto-incrementing, Skitch/Flameshot style)
- ✅ Blur / pixelate / redact regions
- ✅ Select tool: move & delete annotations; live restyle of selection
- ✅ Color + stroke-width pickers in the tool bar
- ✅ Copy / Save flattened result at full capture resolution
- 🚧 Drag-resize handles on the selected annotation (move only for now)
- ⬜ Crop & resize the capture region while annotating (Xnip behavior)
- ⬜ Font-size picker for the text tool; rotate/scale handles

## v0.3 — Pin, pick, measure

- ⬜ Pin image to screen — always-on-top floating window (opacity, click-through)
- ⬜ Color picker with magnifier loupe (hex/RGB copy)
- ⬜ Screen ruler / pixel measurement (Shottr-style)
- ⬜ Physical-unit size indicator for a selection (Xnip)
- ⬜ Multi-window capture — hold ⇧ to grab several windows at once (Xnip)

## v0.4 — Scrolling capture

- ⬜ Auto-scroll + stitch for full-page screenshots (web pages, docs, chats)
- ⬜ Overlap detection with fixed-header handling
- ⬜ Accessibility-permission-driven programmatic scrolling

## v0.5 — Recording & OCR

- ⬜ Screen recording via ScreenCaptureKit → MP4/MOV (AVAssetWriter)
- ⬜ Export recording as optimized GIF
- ⬜ Optional microphone / system audio
- ⬜ OCR — extract text from any capture via the Vision framework

## v0.6 — Share polish & preferences

- ✅ Settings window with **rebindable capture hotkeys** (recorder UI) + live re-registration
- ✅ Output options: open-editor, copy-to-clipboard, save-to-file, format, save location, sound
- 🚧 Preferences tabs: Capture · Annotate · Recording · Hotkeys · Output · Appearance (single pane today)
- ⬜ Backgrounds, shadows, and frames for share-ready images (CleanShot style)
- ⬜ Formats: HEIC / PDF / GIF / MP4 (PNG/JPG today)
- ⬜ Launch at login (SMAppService)
- ⬜ Capture history / recent captures browser
- ⬜ Export / import settings as JSON

Ideas drawn from Xnip, CleanShot X, Shottr, Flameshot, and Skitch.
