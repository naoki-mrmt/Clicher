# CLAUDE.md — Clicher

## プロジェクト概要

ClicherはmacOS用のスクリーンショット＆アノテーションアプリ。プロ向けキャプチャ機能をSwiftUI + AppKitでネイティブ実装する。

## 併用スキル・ルール

このプロジェクトでは以下のスキルとルールを併用する。SwiftUI コードを書く際は必ずこれらに準拠すること。

| ファイル | 内容 | 用途 |
|---------|------|------|
| `AGENTS.md` | Paul Hudson の Swift/SwiftUI コーディングガイド | Swift全般のモダンAPI・アンチパターン回避 |
| `.claude/skills/swiftui-pro/` | Paul Hudson の SwiftUI Pro スキル | SwiftUIコードレビュー・deprecated API検出 |
| `.claude/skills/swiftui-expert/` | Antoine van der Lee の SwiftUI Expert | macOSシーン・ウィンドウスタイリング・パフォーマンス |
| `.claude/skills/swift-concurrency-pro/` | Paul Hudson の Swift Concurrency Pro | async/await・Actor・構造化並行処理・バグパターン検出 |
| `.claude/skills/swift-testing-pro/` | Paul Hudson の Swift Testing Pro | Swift Testing フレームワーク・XCTestからの移行 |
| `.claude/skills/swiftdata-pro/` | Paul Hudson の SwiftData Pro | SwiftData モデル設計・CloudKit・インデックス |
| `.claude/skills/clicher-dev/` | プロジェクト固有スキル | 実際のモジュール構成・キャプチャフロー・実装パターン |

**重要**: SwiftUI コードを書く・レビューする際は `swiftui-pro` と `swiftui-expert` のリファレンスを参照すること。特に macOS 固有の実装では `swiftui-expert/references/macos-scenes.md`、`macos-views.md`、`macos-window-styling.md` が必須。並行処理コードは `swift-concurrency-pro` を、テストコードは `swift-testing-pro` を参照すること。

**注**: `.agents/skills` は `.claude/skills` へのシンボリックリンク。スキルの編集は `.claude/skills/` 側だけで行う。

## 技術スタック

- **言語**: Swift 6 (strict concurrency, `.swiftLanguageMode(.v6)`)
- **UI**: SwiftUI + AppKit（メニューバー・オーバーレイはAppKit）
- **キャプチャ**: ScreenCaptureKit (macOS 14+)
- **画像処理**: CoreGraphics + CoreImage
- **OCR**: Vision Framework
- **録画**: SCStream + AVAssetWriter（GIF変換・トリムも対応）
- **パッケージ管理**: SPM マルチモジュール
- **最小OS**: macOS 14 Sonoma

## プロジェクト構造

```
Clicher/
├── Clicher/                  # アプリ本体（ClicherApp.swift, AppDelegate.swift, Assets）
├── Clicher.xcodeproj
├── ClicherTests/             # アプリ統合テスト（Swift Testing）
├── ClicherUITests/           # XCUITest（XCTest ベース、唯一の例外）
├── Packages/
│   ├── CaptureEngine/        # キャプチャフロー・オーバーレイ・録画・スクロール・OCR
│   ├── AnnotateEngine/       # 画像編集・アノテーション
│   ├── OverlayUI/            # QuickAccess・設定・メニューバー等のUI
│   ├── SharedModels/         # 共通型（AppState, CaptureMode, AnnotationItem, BrandPreset…）
│   └── Utilities/            # ホットキー、権限、エクスポート、ブランドプリセット永続化
├── Scripts/                  # build-release.sh / create-release.sh / generate-appcast.sh
└── Distribution/             # homebrew-cask テンプレート
```

各パッケージは `Sources/` と `Tests/` を持つ。モジュールの詳細は `.claude/skills/clicher-dev/SKILL.md` を参照。

## コーディング規約

### Swift スタイル
- Swift 6 strict concurrency を使用。`@Sendable`, `@MainActor` を適切に付与。`swift-concurrency-pro` スキルに準拠
- `@Observable` マクロを使用（ObservableObject は使わない）
- サービスはProtocolで抽象化（例: `ScreenCaptureServiceProtocol`）し、テストでモック注入できるようにする
- 命名: lowerCamelCase (変数/関数), UpperCamelCase (型), SCREAMING_SNAKE不使用
- async/await を優先。クロージャベースの非同期APIは使わない（AppKitデリゲート等のブリッジは例外）
- 共有状態は `@MainActor` または actor で保護

### アーキテクチャパターン
- TCA不使用。素のSwiftUI + AppKit
- 状態管理は `@Observable` クラス + SwiftUI の `@State` / `@Environment`
- キャプチャフローは `CaptureCoordinator`（@MainActor @Observable）がコールバックで統括
- AppKit部分は `NSViewRepresentable` / `NSHostingView` でブリッジ
- 依存注入は `@Environment` またはイニシャライザ注入
- アノテーションツールは `AnnotationToolType` enum ベース（ツールProtocolは存在しない）

### ファイル構成
- 1ファイル1型を基本とする（小さなヘルパーは例外）
- SPMパッケージごとに `Sources/` と `Tests/` を分離
- Public APIには必ずドキュメントコメント (`///`) を付ける

## 重要な実装パターン

### ScreenCaptureKit
```swift
// ✅ 正しい: SCScreenshotManager.captureImage を使用（ウィンドウ・全画面）
let image = try await SCScreenshotManager.captureImage(
    contentFilter: filter,
    configuration: config
)
```

**例外**: エリアキャプチャ（`ScreenCaptureService.captureArea`）のみ、`SCScreenshotManager` の
`sourceRect` バグ回避のため意図的に `CGWindowListCreateImage` を使用している。
deprecated 警告は承知の上での選択なので、機械的に SCK へ「修正」しないこと。

### ショートカット設計

ユーザーが覚えるショートカットは `⌘⇧A` の1つだけ（設定画面でカスタム割り当て可能）。

```
⌘⇧A → 録画中なら停止 / それ以外は Lark 風キャプチャ開始
      → エリア選択（AreaSelectionOverlay）
      → インライン編集（InlineAnnotateOverlay: ツールバー + モードタブバー）
         タブバーで エリア/ウィンドウ/全画面/スクロール/OCR/録画 に切替
      → QuickAccessOverlay（コピー/保存/編集/ピン留め）
```

旧設計のHUDパネル方式（⌘⇧A → HUD → 数字キー）は廃止済み。メニューバーからも各モードを直接起動できる。

### グローバルホットキー
```swift
// CGEvent tap で実装（Utilities/HotkeyManager.swift）。Accessibility権限が必要
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

- キーボード入力を受けるパネルは `canBecomeKey == true` のサブクラスにする
- `close()` するウィンドウは `isReleasedWhenClosed = false` を設定（二重解放クラッシュ防止）

## テスト方針

**Swift Testing フレームワークを使用**（XCTest は使わない）。`swift-testing-pro` スキルに準拠すること。
**唯一の例外**: `ClicherUITests/` の XCUITest は XCTest が必須（Swift Testing は UI テスト非対応）。

- CaptureEngine: `ScreenCaptureServiceProtocol` 経由でモック注入。実キャプチャを発火させるテストは書かない
- AnnotateEngine: ドキュメントの状態遷移と描画結果のユニットテスト
- OverlayUI: 状態遷移のユニットテスト
- ファイルI/Oは実ユーザーディレクトリでなく temp dir + `defer` cleanup
- 列挙系は `@Test(arguments: X.allCases)` でパラメータ化
- 手動テスト: キャプチャフローのE2Eは手動確認

```swift
// ✅ Swift Testing を使う
import Testing

@Suite("CaptureEngine Tests")
struct CaptureEngineTests {
    @Test("Service initializes correctly")
    @MainActor func serviceInit() {
        let service = ScreenCaptureService()
        #expect(!service.isCapturing)
    }
}
```

## ビルド・実行

```bash
# パッケージ単体テスト（CIと同じ）
swift test --package-path Packages/SharedModels   # 各パッケージ同様

# アプリビルド
xcodebuild -scheme Clicher -configuration Debug build

# アプリ統合テスト（UIテストを除外）
xcodebuild -scheme Clicher -configuration Debug test -only-testing:ClicherTests

# リリースは /release スキル（Scripts/create-release.sh）を使用
```

**CI**: `.github/workflows/test.yml` が全パッケージの `swift test` + アプリビルドを実行する。
**リリース前にCIがグリーンであることを確認すること。**

## 権限要件

- **Screen Recording**: ScreenCaptureKit使用に必須
- **Accessibility**: グローバルホットキーに必須
- **Sandbox**: 無効（直接配布のため）

## よくある落とし穴

1. `SCShareableContent.current` は非同期。メインスレッドをブロックしない
2. `NSPanel` の `level` 設定を間違えるとキャプチャUI自体がキャプチャされる
3. Screen Recording権限は一度拒否されるとシステム設定からのみ変更可能 → 丁寧なガイドUI必要
4. Retina対応: `CGImage` のサイズはピクセル単位。スケール係数は**ターゲット画面**（カーソル下の画面ではない）から取得する
5. グローバル座標のY反転は**プライマリ画面**（`NSScreen.screens.first`）の高さで行う。マウス下の画面を使うとマルチディスプレイで壊れる
6. `CGEvent.tapCreate` は Accessibility権限なしだと `nil` を返す
7. `NSWindow.close()` はデフォルトで自己解放する（`isReleasedWhenClosed`）。強参照を持つなら必ず false に
8. `CaptureCoordinator.isCapturing` のリセット漏れ（エラー・キャンセル経路）は全キャプチャ機能の停止につながる。終了経路を追加したら必ず確認
9. シークレット（notarization パスワード等）はスクリプト・コメントに書かない。`.env`（gitignore済み）経由で渡す

## ブランドプリセット設計（実装済み）

全キャプチャにブランド設定を自動適用する機能。

### BrandPreset モデル（SharedModels/BrandPreset.swift）
```swift
struct BrandPreset: Codable, Identifiable {
    let id: UUID
    var name: String               // "Client A", "自社ブランド"
    var primaryColor: CodableColor
    var secondaryColor: CodableColor
    var accentColor: CodableColor
    var logoImageData: Data?       // PNG バイナリ
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
- **Export**: `WatermarkRenderer` でロゴウォーターマーク挿入
- **設定UI**: `BrandPresetSettingsView`（CRUD + インポート/エクスポート）

### ストレージ（Utilities/BrandPresetStore.swift）
- `~/Library/Application Support/Clicher/presets/` に JSON 保存
- ロゴ画像は同ディレクトリに `{presetId}.logo.png` で保存
- `.clipreset` 形式でチーム共有可能

## Phase管理

- **Phase 1（MVP）: 完了** — エリア/ウィンドウ/全画面キャプチャ、QuickAccess、アノテーション、Undo/Redo、グローバルホットキー
- **Phase 2（ブランドプリセット）: 完了** — プリセットCRUD、デフォルト色反映、ウォーターマーク、`.clipreset`
- **Phase 3 相当（先行実装済み）** — 画面録画、スクロールキャプチャ、OCR、GIF変換、動画トリム
- **現在**: 品質・安定性の改善フェーズ（マルチディスプレイ対応、状態管理の堅牢化、テスト拡充）

## モデル選択ガイド

- **Opus**: アーキテクチャ設計、複雑なアルゴリズム（スクロールスティッチング等）、Phase計画の見直し
- **Sonnet**: 個別ツールの実装、UIコンポーネント作成、テスト記述、リファクタリング
