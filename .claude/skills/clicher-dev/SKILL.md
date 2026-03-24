---
name: clicher-dev
description: "Clicher（macOS スクリーンショット & アノテーションツール）の開発スキル。SwiftUI + AppKit + ScreenCaptureKit で構築。以下の場合に使用: (1)Clicher の機能実装 (2)キャプチャ・アノテーション関連のSwiftコード (3)NSPanel/NSView/CALayer を使ったオーバーレイやキャンバス実装 (4)ScreenCaptureKit の統合 (5)Homebrew Cask/Sparkle 配布設定 (6)ブランドプリセット・ウォーターマーク・ブランドカラー自動適用。「スクショアプリ」「Clicher」「キャプチャ」「アノテーション」「ブランドプリセット」等のキーワードでも発動する。"
---

# Clicher 開発スキル

macOS スクリーンショット & アノテーションツール「Clicher」の開発における実装パターン集。

## 技術スタック

| 要素 | 技術 |
|------|------|
| UI | SwiftUI + AppKit |
| アーキテクチャ | MVVM + @Observable |
| キャプチャ | ScreenCaptureKit (macOS 14+) |
| 画像処理 | Core Image + Core Graphics |
| OCR | Vision framework |
| ホットキー | Carbon API (RegisterEventHotKey) |
| パッケージ | SPM マルチモジュール |

## モジュール一覧

- **CaptureEngine**: スクリーンキャプチャの核。ScreenCaptureKit ラッパー
- **Annotator**: アノテーション/編集エンジン。NSView + CALayer ベース
- **QuickOverlay**: 撮影後のフローティングUI (NSPanel)
- **BackgroundTool**: スクショ背景の追加・カスタマイズ
- **ImageProcessor**: 画像変換、エクスポート、クリップボード
- **OCREngine**: Vision framework によるテキスト認識
- **HotkeyManager**: グローバルショートカット管理
- **BrandPreset**: ブランドプリセット管理。カラー/ロゴ/フォント設定をプリセットとして保存し、Annotate・Background・Exportに自動適用
- **SettingsUI**: 設定画面
- **Recorder**: 画面録画 (Phase 3)
- **CloudSync**: クラウドアップロード (Phase 3)
- **Shared**: 共通モデル、Extensions、ユーティリティ

## 実装パターン

### 1. ScreenCaptureKit でスクリーンショット

```swift
import ScreenCaptureKit

actor ScreenCapturer {
    func captureFullScreen(display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2  // Retina
        config.height = display.height * 2
        config.showsCursor = false
        
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
    
    func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.capturesShadowsOnly = false
        config.shouldBeOpaque = false  // 影付き透過
        
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
    
    func captureArea(rect: CGRect, display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width) * 2
        config.height = Int(rect.height) * 2
        config.showsCursor = false
        
        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }
}
```

### 2. エリア選択オーバーレイ

```swift
import AppKit

class AreaSelectorPanel: NSPanel {
    private var selectionRect: CGRect = .zero
    private var startPoint: CGPoint = .zero
    
    init(screen: NSScreen) {
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.contentView = AreaSelectorView()
    }
}

class AreaSelectorView: NSView {
    var selectionRect: CGRect = .zero
    var onSelectionComplete: ((CGRect) -> Void)?
    
    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionRect.origin = point
    }
    
    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        selectionRect.size = CGSize(
            width: point.x - selectionRect.origin.x,
            height: point.y - selectionRect.origin.y
        )
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        onSelectionComplete?(selectionRect.standardized)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        // 半透明の暗いオーバーレイ
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()
        
        // 選択範囲を切り抜き（明るく表示）
        guard !selectionRect.isEmpty else { return }
        let path = NSBezierPath(rect: selectionRect.standardized)
        NSColor.clear.setFill()
        path.fill(using: .clear)
        
        // 選択枠の白い境界線
        NSColor.white.setStroke()
        path.lineWidth = 1.0
        path.stroke()
    }
}
```

### 3. キャプチャHUD（⌘⇧A で起動）

```swift
import AppKit
import SwiftUI

/// ⌘⇧A で表示されるキャプチャモード選択HUD
class CaptureHUDPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.hidesOnDeactivate = true
        self.collectionBehavior = [.canJoinAllSpaces, .transient]
        
        // SwiftUI View をホスト
        self.contentView = NSHostingView(rootView: CaptureHUDView(
            onModeSelected: { [weak self] mode in
                self?.close()
                // → CaptureEngine でモード実行
            }
        ))
        
        // 画面中央に配置
        if let screen = NSScreen.main {
            let x = (screen.frame.width - frame.width) / 2
            let y = (screen.frame.height - frame.height) / 2
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

struct CaptureHUDView: View {
    let onModeSelected: (CaptureMode) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Clicher")
                .font(.headline)
            
            HStack(spacing: 12) {
                hudButton("1", icon: "rectangle.dashed", label: "エリア", mode: .area)
                hudButton("2", icon: "macwindow", label: "ウィンドウ", mode: .window)
                hudButton("3", icon: "display", label: "全画面", mode: .fullscreen)
            }
            // Phase 2-3 のモードは後から追加
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .onKeyPress(.escape) { dismiss(); return .handled }
    }
    
    private func hudButton(_ key: String, icon: String, label: String, mode: CaptureMode) -> some View {
        Button { onModeSelected(mode) } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2)
                Text(label).font(.caption)
                Text(key).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(width: 100, height: 80)
        }
        .buttonStyle(.plain)
        .onKeyPress(KeyEquivalent(Character(key))) { onModeSelected(mode); return .handled }
    }
}
```

### 4. Quick Access Overlay

```swift
class QuickAccessPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        // 他アプリのフォーカスを奪わない
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true
    }
    
    func show(with image: NSImage, at position: OverlayPosition) {
        // SwiftUI HostingView をセット
        let overlayView = QuickAccessOverlayView(
            image: image,
            onCopy: { [weak self] in self?.copyToClipboard(image) },
            onSave: { [weak self] in self?.saveToFile(image) },
            onEdit: { [weak self] in self?.openAnnotator(image) },
            onDrag: { [weak self] in self?.startDrag(image) }
        )
        self.contentView = NSHostingView(rootView: overlayView)
        
        // 位置を計算
        let frame = calculateFrame(for: position)
        self.setFrame(frame, display: true)
        self.orderFront(nil)
    }
}
```

### 5. アノテーション ツール Protocol

```swift
protocol AnnotationTool {
    var toolType: ToolType { get }
    var cursor: NSCursor { get }
    
    func mouseDown(at point: CGPoint, in canvas: AnnotationCanvas)
    func mouseDragged(to point: CGPoint, in canvas: AnnotationCanvas)
    func mouseUp(at point: CGPoint, in canvas: AnnotationCanvas)
    func keyDown(with event: NSEvent, in canvas: AnnotationCanvas)
}

enum ToolType: String, CaseIterable {
    case arrow, rectangle, filledRectangle, ellipse, line
    case text, pixelate, blur, spotlight
    case counter, pencil, highlighter, crop
    
    var shortcutKey: Character? {
        switch self {
        case .arrow: return "a"
        case .rectangle: return "r"
        case .text: return "t"
        case .pencil: return "p"
        case .highlighter: return "h"
        case .blur: return "b"
        case .counter: return "n"
        case .crop: return "c"
        default: return nil
        }
    }
}
```

### 6. グローバルホットキー登録

```swift
import Carbon

class HotkeyRegistrar {
    private var hotkeyRef: EventHotKeyRef?
    
    func register(
        keyCode: UInt32,
        modifiers: UInt32,
        id: UInt32,
        handler: @escaping () -> Void
    ) {
        var hotKeyID = EventHotKeyID(signature: 0x434C4943, id: id) // "CLIC"
        var eventType = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        // ハンドラの登録
        let handlerRef = Unmanaged.passRetained(handler as AnyObject)
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let handler = Unmanaged<AnyObject>.fromOpaque(userData)
                    .takeUnretainedValue() as! () -> Void
                handler()
                return noErr
            },
            1, &eventType,
            handlerRef.toOpaque(),
            nil
        )
        
        RegisterEventHotKey(
            keyCode, modifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotkeyRef
        )
    }
}
```

### 7. ピクセル化（モザイク）

```swift
import CoreImage

func pixelate(image: CGImage, rect: CGRect, blockSize: Int = 10) -> CGImage? {
    let ciImage = CIImage(cgImage: image)
    
    // 指定範囲を切り出し
    let cropped = ciImage.cropped(to: rect)
    
    // ピクセル化フィルタ
    guard let filter = CIFilter(name: "CIPixellate") else { return nil }
    filter.setValue(cropped, forKey: kCIInputImageKey)
    filter.setValue(blockSize, forKey: kCIInputScaleKey)
    filter.setValue(CIVector(cgPoint: rect.origin), forKey: kCIInputCenterKey)
    
    guard let output = filter.outputImage else { return nil }
    
    // 元画像に合成
    let composited = output.composited(over: ciImage)
    
    let context = CIContext()
    return context.createCGImage(composited, from: ciImage.extent)
}
```

### 8. ブランドプリセット

```swift
import Foundation

// MARK: - モデル定義

struct BrandPreset: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var primaryColor: CodableColor
    var secondaryColor: CodableColor
    var accentColor: CodableColor
    var logoImageData: Data?
    var logoPosition: LogoPosition
    var logoOpacity: Double
    var fontName: String?
    var fontSize: CGFloat
    var backgroundGradient: GradientConfig?
    var exportSettings: ExportConfig?
    var isDefault: Bool
    
    static let empty = BrandPreset(
        id: UUID(), name: "New Preset",
        primaryColor: .init(hex: "#007AFF"),
        secondaryColor: .init(hex: "#5856D6"),
        accentColor: .init(hex: "#FF9500"),
        logoPosition: .bottomRight, logoOpacity: 0.3,
        fontSize: 14, isDefault: false
    )
}

enum LogoPosition: String, Codable, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight, center
}

// MARK: - プリセットマネージャー

@Observable
class BrandPresetManager {
    private(set) var presets: [BrandPreset] = []
    var activePreset: BrandPreset? {
        presets.first(where: \.isDefault) ?? presets.first
    }
    
    private let storageURL: URL = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        return appSupport.appendingPathComponent("Clicher/presets")
    }()
    
    func load() throws {
        let url = storageURL.appendingPathComponent("presets.json")
        let data = try Data(contentsOf: url)
        presets = try JSONDecoder().decode([BrandPreset].self, from: data)
    }
    
    func save() throws {
        try FileManager.default.createDirectory(
            at: storageURL, withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(presets)
        try data.write(to: storageURL.appendingPathComponent("presets.json"))
    }
    
    func setDefault(_ preset: BrandPreset) {
        for i in presets.indices {
            presets[i].isDefault = (presets[i].id == preset.id)
        }
    }
    
    // .clipreset のエクスポート（JSON + ロゴをzip化）
    func exportPreset(_ preset: BrandPreset, to url: URL) throws {
        // JSON + logo data を zip アーカイブにまとめる
        let json = try JSONEncoder().encode(preset)
        // ZIPは Archive framework or カスタム実装
    }
}

// MARK: - Annotate連携：ブランドカラーの自動適用

extension AnnotationCanvas {
    func applyBrandDefaults(from preset: BrandPreset) {
        // ツールのデフォルト色をブランドカラーに設定
        toolSettings.defaultStrokeColor = preset.primaryColor.nsColor
        toolSettings.defaultFillColor = preset.secondaryColor.nsColor
        toolSettings.defaultTextColor = preset.primaryColor.nsColor
        if let fontName = preset.fontName {
            toolSettings.defaultFont = NSFont(name: fontName, size: preset.fontSize)
                ?? .systemFont(ofSize: preset.fontSize)
        }
    }
}

// MARK: - エクスポート時のロゴウォーターマーク

func applyWatermark(
    to image: CGImage,
    logo: CGImage,
    position: LogoPosition,
    opacity: Double,
    padding: CGFloat = 16
) -> CGImage? {
    let width = image.width
    let height = image.height
    let logoSize = CGSize(
        width: min(CGFloat(logo.width), CGFloat(width) * 0.15),
        height: min(CGFloat(logo.height), CGFloat(height) * 0.15)
    )
    
    guard let context = CGContext(
        data: nil, width: width, height: height,
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    context.setAlpha(opacity)
    
    let logoRect: CGRect = {
        switch position {
        case .topLeft:     return CGRect(x: padding, y: CGFloat(height) - logoSize.height - padding, width: logoSize.width, height: logoSize.height)
        case .topRight:    return CGRect(x: CGFloat(width) - logoSize.width - padding, y: CGFloat(height) - logoSize.height - padding, width: logoSize.width, height: logoSize.height)
        case .bottomLeft:  return CGRect(x: padding, y: padding, width: logoSize.width, height: logoSize.height)
        case .bottomRight: return CGRect(x: CGFloat(width) - logoSize.width - padding, y: padding, width: logoSize.width, height: logoSize.height)
        case .center:      return CGRect(x: (CGFloat(width) - logoSize.width) / 2, y: (CGFloat(height) - logoSize.height) / 2, width: logoSize.width, height: logoSize.height)
        }
    }()
    
    context.draw(logo, in: logoRect)
    return context.makeImage()
}
```

## テスト方針

- **CaptureEngine**: 権限モック + SCContentFilter の構築を検証
- **Annotator**: 各ツールの座標計算、レイヤー追加/削除をユニットテスト
- **ImageProcessor**: 画像変換の入出力をスナップショットテスト
- **HotkeyManager**: キーコード変換のユニットテスト
- **BrandPresetManager**: プリセットのCRUD、デフォルト設定切り替え、JSON永続化のユニットテスト
- **UI テスト**: XCUITest でキャプチャ→編集→保存フローの統合テスト

## 実装時のチェックリスト

新しいアノテーションツールを追加する時：

1. `AnnotationTool` protocol に準拠した struct/class を作成
2. `ToolType` enum にケースを追加
3. 対応する CALayer サブクラスを作成（描画ロジック）
4. `AnnotationCanvas` のツール切替ロジックに追加
5. ツールバーにアイコンを追加
6. ショートカットキーを `ToolType.shortcutKey` に登録
7. Undo/Redo 対応を確認
8. **ブランドプリセットのデフォルト色が反映されることを確認**
9. ユニットテストを追加

新しいキャプチャモードを追加する時：

1. `CaptureMode` enum にケースを追加
2. `ScreenCapturer` に対応メソッドを実装
3. All-In-One UI にモードを追加
4. ホットキー設定に追加
5. Quick Access Overlay からの遷移を確認

ブランドプリセットを更新する時：

1. `BrandPreset` モデルのプロパティ変更
2. `BrandPresetManager` の保存/読み込みロジック更新
3. Annotate ツールへの自動適用ポイントを確認
4. Background Tool への連携を確認
5. エクスポート時のウォーターマーク適用を確認
6. `.clipreset` のインポート/エクスポート互換性テスト
