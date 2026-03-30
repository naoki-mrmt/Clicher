<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/github/v/release/naoki-mrmt/Clicher" alt="Release">
  <img src="https://img.shields.io/github/license/naoki-mrmt/Clicher" alt="License">
</p>

# Clicher

English / [日本語](./README-ja.md)

All-in-one screenshot tool for macOS. Capture, annotate, record, OCR — one app.

## What it does

- **Capture** — area select, window, fullscreen, scroll stitch, self-timer
- **OCR** — Japanese/English text recognition, QR code scanning
- **Record** — MP4 output, system audio + mic, GIF export
- **Annotate** — arrow, rectangle, text, pixelate, highlight, pencil, crop, etc.
- **Background** — gradient / solid, padding, corner radius, shadow, SNS size presets
- **Brand** — color / logo / font presets, auto-watermark, `.clipreset` sharing
- **Floating** — pin screenshots to desktop, opacity control, click-through
- **History** — thumbnail gallery, re-edit
- **Video edit** — trim, quality change, GIF conversion
- **Image tools** — combine (H/V), rotate, flip

## Install

### Homebrew

```bash
brew tap naoki-mrmt/clicher
brew install --cask clicher
```

### DMG

Grab the `.dmg` from [Releases](https://github.com/naoki-mrmt/Clicher/releases), drag `Clicher.app` to `/Applications`.

### Build from source

```bash
git clone https://github.com/naoki-mrmt/Clicher.git
cd Clicher
xcodebuild -scheme Clicher -configuration Release build
```

## Usage

Hit **`Cmd+Shift+A`** to open the HUD. Pick a mode with number keys.

```
Cmd+Shift+A → [1] Area  [2] Window  [3] Fullscreen
               [4] Scroll [5] OCR    [6] Record
```

After capture, an overlay pops up — save, copy, edit, or pin.

### Permissions

You need to grant these on first launch. Restart the app after.

| Permission | Used for | Where |
|------------|----------|-------|
| Screen Recording | All capture | System Settings → Privacy & Security → Screen Recording |
| Accessibility | `Cmd+Shift+A` hotkey | System Settings → Privacy & Security → Accessibility |

## Architecture

SPM multi-module. Swift 6 strict concurrency.

```
Packages/
├── SharedModels     # Type definitions
├── Utilities        # Settings, permissions, export, history
├── CaptureEngine    # Capture, OCR, recording, scroll
├── AnnotateEngine   # Drawing, background tool
└── OverlayUI        # HUD, overlays, settings
```

SwiftUI + AppKit / ScreenCaptureKit / Vision / AVFoundation

## Requirements

macOS 14 Sonoma or later. Apple Silicon and Intel.

## Development

```bash
# Tests
for pkg in SharedModels Utilities CaptureEngine AnnotateEngine OverlayUI; do
  swift test --package-path "Packages/$pkg"
done

# E2E
xcodebuild test -scheme Clicher -only-testing:ClicherTests

# Release build
./Scripts/build-release.sh --skip-notarize
```

## Contributing

Fork → branch → PR. See [commit-rules.md](.claude/skills/_shared/git/commit-rules.md) for commit conventions.

## License

[MIT](LICENSE)
