<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/github/v/release/naoki-mrmt/Clicher" alt="Release">
  <img src="https://img.shields.io/github/license/naoki-mrmt/Clicher" alt="License">
</p>

# Clicher

> A powerful screenshot & annotation tool for macOS, built natively with SwiftUI + AppKit.

macOS 向けのオールインワン スクリーンショットツール。キャプチャ、アノテーション、録画、OCR を 1 つのアプリで。

---

## Features

| Category | Features |
|----------|----------|
| **Capture** | Area, Window, Fullscreen, Scroll (auto-stitch), Self-timer (3/5/10s) |
| **OCR** | Text recognition (ja/en), QR code & barcode detection |
| **Recording** | MP4 (H.264, 30fps), system audio + mic, GIF export |
| **Annotate** | Arrow, Rectangle, Ellipse, Text, Pixelate, Highlight, Counter, Pencil, Crop |
| **Background** | Solid / Gradient, padding, corner radius, shadow, SNS presets |
| **Brand** | Color / Logo / Font presets, auto-watermark, `.clipreset` team sharing |
| **Floating** | Pin screenshots on screen, opacity control, click-through |
| **History** | Thumbnail gallery, re-edit, Finder integration |
| **Video Editor** | Trim, quality change, GIF conversion |
| **Utilities** | Image combine (H/V), rotate, flip |

## Install

### Homebrew (recommended)

```bash
brew tap naoki-mrmt/clicher
brew install --cask clicher
```

### Download DMG

Download the latest `.dmg` from [Releases](https://github.com/naoki-mrmt/Clicher/releases), open it, and drag `Clicher.app` to `/Applications`.

### Build from source

```bash
git clone https://github.com/naoki-mrmt/Clicher.git
cd Clicher
xcodebuild -scheme Clicher -configuration Release build
```

## Quick Start

### 1. Grant permissions

On first launch, Clicher will ask for two permissions:

| Permission | Required for | Where to enable |
|------------|-------------|-----------------|
| **Screen Recording** | Capture | System Settings > Privacy & Security > Screen Recording |
| **Accessibility** | Global hotkey | System Settings > Privacy & Security > Accessibility |

Restart the app after granting permissions.

### 2. Capture

Press **`Cmd+Shift+A`** to open the Capture HUD, then select a mode:

```
 Cmd+Shift+A  →  HUD  →  [1] Area  [2] Window  [3] Fullscreen
                          [4] Scroll [5] OCR    [6] Record
```

### 3. Quick Actions

After capture, the Quick Access Overlay appears with:

- **Save** — Save to your configured folder
- **Copy** — Copy to clipboard
- **Edit** — Open annotation editor
- **Pin** — Float on screen

## Architecture

Clicher is built as a **multi-module SPM project** with strict Swift 6 concurrency.

```
Clicher/
├── App/                  # Entry point (ClicherApp, AppDelegate)
├── Packages/
│   ├── SharedModels      # CaptureMode, BrandPreset, AnnotationItem, ...
│   ├── Utilities         # Settings, Permissions, Export, History, Hotkey
│   ├── CaptureEngine     # ScreenCaptureKit, OCR, Recording, Scroll
│   ├── AnnotateEngine    # Canvas, Renderer, Background Tool, Editor
│   └── OverlayUI         # HUD, QuickAccess, Settings, Floating, Video Editor
└── Scripts/              # build-release.sh, create-release.sh
```

### Tech Stack

- **Swift 6** — strict concurrency with `@Sendable`, `@MainActor`, actors
- **SwiftUI + AppKit** — SwiftUI for views, AppKit for panels & overlays
- **ScreenCaptureKit** — modern screen capture API (macOS 14+)
- **Vision** — OCR and barcode detection
- **AVFoundation** — recording and video editing

## Requirements

- **macOS 14 Sonoma** or later
- Apple Silicon or Intel

## Development

```bash
# Run all package tests (88 tests)
for pkg in SharedModels Utilities CaptureEngine AnnotateEngine OverlayUI; do
  swift test --package-path "Packages/$pkg"
done

# Run E2E integration tests (12 tests)
xcodebuild test -scheme Clicher -configuration Debug \
  -destination 'platform=macOS' -only-testing:ClicherTests

# Build release DMG
./Scripts/build-release.sh --skip-notarize
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (see [commit conventions](.claude/skills/_shared/git/commit-rules.md))
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
