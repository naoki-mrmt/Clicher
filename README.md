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

- **Capture** — area select, window (click), fullscreen, self-timer
- **OCR** — Japanese/English text recognition with copyable result panel, QR code scanning
- **Record** — MP4 output, system audio + mic toggle, post-recording GIF export
- **Annotate** — arrow, rectangle, ellipse, text, pixelate, highlight, pencil, crop, counter, etc.
- **Background** — gradient / solid, padding, corner radius, shadow, SNS size presets
- **Brand** — color / logo / font presets, auto-watermark, `.clipreset` sharing
- **Floating** — pin screenshots to desktop, opacity control, click-through
- **Video edit** — trim, quality change
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

Hit **`Cmd+Shift+A`** to start capturing. The selection overlay supports two gestures:

- **Drag** → area capture (or recording / OCR if you switched modes from the top tab bar)
- **Click on a window** → captures that whole window (windows under the cursor highlight in blue)

Switch modes using the tab bar shown at the top of the selection overlay:

```
[ Screenshot ] [ Screen Recording ] [ Recognize Text ]
```

After capture, an editing overlay pops up — annotate, save, copy, or pin.

For OCR, a centered panel shows the recognized text with selection support and a "Copy All" button.

For recording, a panel offers Save / Copy file path / GIF / Reveal in Finder after stopping.

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
├── Utilities        # Settings, permissions, export
├── CaptureEngine    # Capture, OCR, recording
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
