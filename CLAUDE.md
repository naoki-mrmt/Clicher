# CLAUDE.md — Clicher

## プロジェクト概要

ClicherはmacOS用のスクリーンショット＆アノテーションアプリ。CleanShot X相当の機能をSwiftUI + AppKitでネイティブ実装する。

## 併用スキル・ルール

このプロジェクトでは以下のスキルとルールを併用する。SwiftUI コードを書く際は必ずこれらに準拠すること。

| ファイル | 内容 | 用途 |
|---------|------|------|
| `AGENTS.md` | Paul Hudson の Swift/SwiftUI コーディングガイド | Swift全般のモダンAPI・アンチパターン回避 |
| `.claude/skills/swiftui-pro/` | Paul Hudson の SwiftUI Pro スキル | SwiftUIコードレビュー・deprecated API検出 |
| `.claude/skills/swiftui-expert/` | Antoine van der Lee の SwiftUI Expert | macOSシーン・ウィンドウスタイリング・パフォーマンス |
| `.claude/skills/clicher-dev/` | プロジェクト固有スキル | ScreenCaptureKit・Annotate・ブランドプリセット実装パターン |

**重要**: SwiftUI コードを書く・レビューする際は `swiftui-pro` と `swiftui-expert` のリファレンスを参照すること。特に macOS 固有の実装では `swiftui-expert/references/macos-scenes.md`、`macos-views.md`、`macos-window-styling.md` が必須。

## 技術スタック

- **言語**: Swift 6 (strict concurrency)
- **UI**: SwiftUI + AppKit（メニューバー・オーバーレイはAppKit）
- **キャプチャ**: ScreenCaptureKit (macOS 14+)
- **画像処理**: CoreGraphics + CoreImage
- **OCR**: Vision Framework
- **録画**: AVFoundation + ScreenCaptureKit
- **パッケージ管理**: SPM マルチモジュール
- **最小OS**: macOS 14 Sonoma

## プロジェクト構造

```
Clicher/
├── App/                      # エントリポイント、AppDelegate
├── Packages/
│   ├── CaptureEngine/        # スクリーンキャプチャ
│   ├── AnnotateEngine/       # 画像編集・アノテーション
│   ├── OverlayUI/            # Quick Access Overlay
│   ├── SharedModels/         # 共通型
│   └── Utilities/            # ホットキー、権限、ファイル管理
├── Resources/
└── Tests/
```

## コーディング規約

### Swift スタイル
- Swift 6 strict concurrency を使用。`@Sendable`, `@MainActor` を適切に付与
- `@Observable` マクロを使用（ObservableObject は使わない）
- Protocol指向設計。ツール・サービスはProtocolで抽象化
- 命名: lowerCamelCase (変数/関数), UpperCamelCase (型), SCREAMING_SNAKE不使用

### アーキテクチャパターン
- TCA不使用。素のSwiftUI + AppKit
- 状態管理は `@Observable` クラス + SwiftUI の `@State` / `@Environment`
- AppKit部分は `NSViewRepresentable` / `NSViewControllerRepresentable` でブリッジ
- 依存注入は `@Environment` またはイニシャライザ注入

### ファイル構成
- 1ファイル1型を基本とする（小さなヘルパーは例外）
- SPMパッケージごとに `Sources/` と `Tests/` を分離
- Public APIには必ずドキュメントコメント (`///`) を付ける

## 重要な実装パターン

### ScreenCaptureKit
```swift
// ✅ 正しい: SCScreenshotManager を使用
let image = try await SCScreenshotManager.captureSampleBuffer(
    contentFilter: filter,
    configuration: config
)

// ❌ 間違い: deprecated API
let image = CGWindowListCreateImage(...)
```

### グローバルホットキー
```swift
// CGEvent tap で実装。Accessibility権限が必要
let eventMask = (1 << CGEventType.keyDown.rawValue)
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: hotkeyCallback,
    userInfo: nil
) else { return }
```

### オーバーレイウィンドウ
```swift
// NSPanel で常に最前面に表示
let panel = NSPanel(
    contentRect: rect,
    styleMask: [.nonactivatingPanel, .fullSizeContentView],
    backing: .buffered,
    defer: false
)
panel.level = .floating
panel.isOpaque = false
panel.backgroundColor = .clear
```

### Annotate ツール Protocol
```swift
protocol AnnotationTool {
    var toolType: ToolType { get }
    func handleMouseDown(at point: CGPoint, in canvas: AnnotateCanvas)
    func handleMouseDragged(to point: CGPoint, in canvas: AnnotateCanvas)
    func handleMouseUp(at point: CGPoint, in canvas: AnnotateCanvas)
    func draw(in context: CGContext)
}
```

## テスト方針

- CaptureEngine: ScreenCaptureKit のモック化が困難なため、Protocol経由で抽象化してユニットテスト
- AnnotateEngine: 各ツールの描画結果をスナップショットテスト
- OverlayUI: 状態遷移のユニットテスト
- 手動テスト: キャプチャフローのE2Eは手動確認

## ビルド・実行

```bash
# ビルド
xcodebuild -scheme Clicher -configuration Debug build

# テスト
xcodebuild -scheme Clicher -configuration Debug test

# リリースビルド
xcodebuild -scheme Clicher -configuration Release archive
```

## 権限要件

- **Screen Recording**: ScreenCaptureKit使用に必須
- **Accessibility**: グローバルホットキーに必須
- **Sandbox**: 無効（直接配布のため）

## よくある落とし穴

1. `SCShareableContent.current` は非同期。メインスレッドをブロックしない
2. `NSPanel` の `level` 設定を間違えるとキャプチャUI自体がキャプチャされる
3. Screen Recording権限は一度拒否されるとシステム設定からのみ変更可能 → 丁寧なガイドUI必要
4. Retina対応: `CGImage` のサイズはピクセル単位。`NSScreen.main?.backingScaleFactor` を考慮
5. `CGEvent.tapCreate` は Accessibility権限なしだと `nil` を返す
6. SwiftUI の `MenuBarExtra` は macOS 13+ だが、カスタマイズ性が低い場合は `NSStatusItem` にフォールバック

## ブランドプリセット設計

Phase 2 で実装するブランドプリセット機能。全キャプチャにブランド設定を自動適用する。

### BrandPreset モデル
```swift
struct BrandPreset: Codable, Identifiable {
    let id: UUID
    var name: String               // "Client A", "自社ブランド"
    var primaryColor: CodableColor
    var secondaryColor: CodableColor
    var accentColor: CodableColor
    var logoImage: Data?           // PNG/SVG バイナリ
    var logoPosition: LogoPosition // .topLeft, .bottomRight, .center 等
    var logoOpacity: Double        // 0.0 - 1.0
    var fontName: String?          // ブランドフォント名
    var fontSize: CGFloat
    var backgroundGradient: GradientConfig? // Background Tool用
    var exportSettings: ExportConfig?       // 出力形式・品質
    var isDefault: Bool
}
```

### 適用ポイント
- **AnnotateEngine**: ツールのデフォルト色をプリセットから取得
- **BackgroundTool**: プリセットのグラデーションを自動生成候補に
- **QuickOverlay**: プリセット切り替えボタン表示
- **Export**: ロゴウォーターマーク自動挿入
- **設定UI**: プリセット管理画面（CRUD + インポート/エクスポート）

### ストレージ
- `~/Library/Application Support/Clicher/presets/` に JSON 保存
- ロゴ画像は同ディレクトリに `{presetId}.logo.png` で保存
- `.clipreset` 形式でチーム共有可能（JSON + ロゴをzip化）

## Phase管理

現在のPhase: **Phase 1（MVP）**

Phase 1 の完了条件:
- [ ] メニューバーからArea/Window/Fullscreenキャプチャが動作
- [ ] Quick Access Overlayでコピー/保存/編集遷移が動作
- [ ] Annotateで矢印/矩形/テキスト/モザイク/クロップが動作
- [ ] Undo/Redo が動作
- [ ] グローバルホットキーが動作

Phase 2 の完了条件（追加分）:
- [ ] ブランドプリセットの作成・編集・削除が動作
- [ ] デフォルトプリセットがAnnotateツールに自動反映
- [ ] ロゴウォーターマークがエクスポート時に適用
- [ ] `.clipreset` のインポート/エクスポートが動作

## モデル選択ガイド

- **Opus**: アーキテクチャ設計、複雑なアルゴリズム（スクロールスティッチング等）、Phase計画の見直し
- **Sonnet**: 個別ツールの実装、UIコンポーネント作成、テスト記述、リファクタリング
