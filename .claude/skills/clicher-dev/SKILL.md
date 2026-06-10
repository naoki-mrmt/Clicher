---
name: clicher-dev
description: "Clicher（macOS スクリーンショット & アノテーションツール）の開発スキル。SwiftUI + AppKit + ScreenCaptureKit で構築。以下の場合に使用: (1)Clicher の機能実装 (2)キャプチャ・アノテーション関連のSwiftコード (3)NSPanel/NSView/CALayer を使ったオーバーレイやキャンバス実装 (4)ScreenCaptureKit の統合 (5)Homebrew Cask/Sparkle 配布設定 (6)ブランドプリセット・ウォーターマーク・ブランドカラー自動適用。「スクショアプリ」「Clicher」「キャプチャ」「アノテーション」「ブランドプリセット」等のキーワードでも発動する。"
---

# Clicher 開発スキル

macOS スクリーンショット & アノテーションツール「Clicher」の実装パターン集。
**このスキルは実コードを正とする。** パターンと実装が食い違う場合は実コードを読み、必要ならこのスキルを更新すること。

## 技術スタック

| 要素 | 技術 |
|------|------|
| UI | SwiftUI + AppKit |
| アーキテクチャ | @Observable + コールバック連携（TCA不使用） |
| キャプチャ | ScreenCaptureKit (macOS 14+) |
| 画像処理 | Core Image + Core Graphics |
| OCR | Vision framework |
| 録画 | SCStream + AVAssetWriter |
| ホットキー | CGEvent tap（Accessibility 権限必須。Carbon は不使用） |
| パッケージ | SPM マルチモジュール（Swift 6, `.swiftLanguageMode(.v6)`） |

## モジュール一覧（実在する5パッケージ + アプリ本体）

| モジュール | 場所 | 内容 |
|-----------|------|------|
| **CaptureEngine** | `Packages/CaptureEngine/` | キャプチャの核。`CaptureCoordinator`（フロー統括）、`ScreenCaptureService`（SCK ラッパー）、`AreaSelectionOverlay` / `WindowSelectionOverlay` / `InlineAnnotateOverlay`（選択・編集オーバーレイ）、`ScreenRecordingSession`、`ScrollCaptureSession` + `ImageStitcher`、`OCRService`、`GIFConverter`、`VideoEditor` |
| **AnnotateEngine** | `Packages/AnnotateEngine/` | 編集ウィンドウ。`AnnotateDocument`（@Observable、Undo/Redo）、`AnnotateCanvasView`（NSView キャンバス）、`AnnotateRenderer`（CGContext 描画）、`AnnotateWindow` / `AnnotateEditorView`、`BackgroundTool` |
| **OverlayUI** | `Packages/OverlayUI/` | `QuickAccessOverlay`（撮影後フローティング）、`MenuBarView`、`SettingsView`、`BrandPresetSettingsView`、`OCRResultPanel`、`FloatingScreenshot`（ピン留め）、`VideoEditorView`、`RecordingIndicator`、`ScrollCaptureControls`、`PermissionGuideView`、`ToastOverlay` |
| **SharedModels** | `Packages/SharedModels/` | `AppState`、`CaptureMode`、`CaptureResult`、`AnnotationItem` / `AnnotationToolType` / `AnnotationStyle`、`BrandPreset`、`ImageFormat`、`L10n` 等の共通型 |
| **Utilities** | `Packages/Utilities/` | `HotkeyManager`（CGEvent tap）、`PermissionManager`、`AppSettings`、`ImageExporter`、`WatermarkRenderer`、`BrandPresetStore`、`ScreenUtilities`、`LoginItemManager`、`UpdateManager`、`Logger+Clicher` |
| アプリ本体 | `Clicher/` | `ClicherApp`（MenuBarExtra + Settings シーン）、`AppDelegate`（ホットキー登録・権限ガイド） |

## キャプチャフロー（Lark 風 UX）

ユーザーが覚えるショートカットは **⌘⇧A の1つだけ**（設定でカスタム可、`AppSettings.hotkeyKeyCode/hotkeyModifiers`）。

```
⌘⇧A
 ├─ 録画中 → 録画停止（AppDelegate のホットキーコールバック）
 └─ それ以外 → CaptureCoordinator.startCapture(mode: .area)
      → AreaSelectionOverlay（全画面 dim + ドラッグ選択）
      → InlineAnnotateOverlay（選択範囲をくり抜き表示 + ツールバー + モードタブバー）
          モードタブバー（ModeTabBarView）から
          エリア / ウィンドウ / 全画面 / スクロール / OCR / 録画 に切替
      → 確定 → QuickAccessOverlay（コピー / 保存 / 編集 / ピン留め）
```

- HUD パネル方式（旧設計）は廃止済み。モード切替は `InlineAnnotateOverlay` 内のタブバーで行う
- メニューバー（`MenuBarView`）からも各モードを直接起動できる
- フロー全体の状態は `CaptureCoordinator`（@MainActor @Observable）が `isCapturing` / `isRecording` で管理。
  **新しい終了経路（エラー・キャンセル含む）を追加したら、必ず `isCapturing` がリセットされることを確認する**（リセット漏れ＝アプリ再起動まで全キャプチャ不能）

## 実装パターン

### 1. ScreenCaptureKit でスクリーンショット（実装: `ScreenCaptureService.swift`）

```swift
// ✅ ウィンドウ・全画面: SCScreenshotManager.captureImage を使用
let filter = SCContentFilter(desktopIndependentWindow: window)
let config = SCStreamConfiguration()
config.showsCursor = false
let image = try await SCScreenshotManager.captureImage(
    contentFilter: filter,
    configuration: config
)
```

**例外**: エリアキャプチャのみ `CGWindowListCreateImage` を意図的に使用している
（`SCScreenshotManager` の `sourceRect` にバグがあるための回避策。`ScreenCaptureService.captureArea` のコメント参照）。
deprecated 警告は承知の上での選択なので、SCK へ「修正」しないこと。挙動を変える場合は
「フルディスプレイを `captureImage` で撮って `CGImage.cropping(to:)` でピクセル座標クロップ」が代替案。

注意点:
- `SCShareableContent.current` は非同期。メインスレッドをブロックしない
- スケール係数は**ターゲット画面**から取る（カーソル下の画面ではない）。`CGImage` はピクセル単位
- 自前のオーバーレイが写り込まないよう、撮影前にオーバーレイを隠す（`SCContentFilter(display:excludingWindows:)` の除外も検討）

### 2. 座標系の変換（実装: `ScreenUtilities.swift`）

3つの座標系が混在する。変換ヘルパーは `ScreenUtilities` に集約すること:

| 座標系 | 原点 | 使用箇所 |
|--------|------|---------|
| AppKit (NSScreen/NSWindow/NSEvent) | **プライマリ画面**左下 | オーバーレイ、マウス座標 |
| CoreGraphics / SCWindow.frame | プライマリ画面左上 | SCK、CGWindowList |
| CGImage | ピクセル単位（スケール倍） | 画像処理 |

**グローバル座標の Y 反転は必ずプライマリ画面（`NSScreen.screens.first`）の高さで行う。**
マウス下の画面（`ScreenUtilities.activeScreen`）の高さを使うとマルチディスプレイで壊れる。

### 3. オーバーレイパネル（実装: `AreaSelectionOverlay.swift` ほか）

```swift
let panel = NSPanel(
    contentRect: screen.frame,
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.level = .screenSaver            // キャプチャ UI 自体が写り込まないレベル設定に注意
panel.isOpaque = false
panel.backgroundColor = .clear
panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
```

- **キーボード入力を受けたいパネル**（ESC・数字キー等）は `canBecomeKey` を `true` に
  オーバーライドした NSPanel サブクラスを使う。borderless + nonactivating のままでは
  ローカルモニタにキーイベントが届かない
- `NSWindow` を `close()` する場合は生成時に `isReleasedWhenClosed = false` を設定する
  （Swift の強参照と二重解放になりクラッシュする）。`orderOut` + 参照破棄でも可
- 継続（continuation）で選択結果を待つオーバーレイには**必ずキャンセル API** を用意し、
  モード切替などで放棄する際に呼ぶ（宙吊り continuation はリーク + 状態破壊の元）

### 4. グローバルホットキー（実装: `Utilities/HotkeyManager.swift`）

CGEvent tap で実装。Carbon (`RegisterEventHotKey`) は使わない。

```swift
// Accessibility 権限がないと tapCreate は nil を返す
guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,   // 他アプリ（Lark 等）より先にイベントを取る
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: hotkeyCallback,
    userInfo: nil
) else { return }
```

- 起動直後に `register()`、`configure()` 後に `reregister()` で優先度を確保する流れは `AppDelegate` 参照
- 修飾キーは `.deviceIndependentFlagsMask` でマスクして**完全一致**で比較（⌘⇧⌥A が ⌘⇧A を誤発火させない）

### 5. アノテーション（実装: `AnnotateEngine` + `SharedModels`）

ツールは protocol ではなく **enum ベース**:
- `AnnotationToolType`（SharedModels）: `.arrow .rectangle .ellipse .line .text .pixelate .highlight .counter .pencil .crop`
- `AnnotationItem`（SharedModels）: 参照型。Undo スナップショット用に `copy()` を持つ（**id は保持**すること）
- `AnnotateDocument`: `items` + `undoStack`/`redoStack`（スナップショット方式、上限50）。
  スナップショットは**実際に変更が起きる直前**に取る（選択クリックだけで取らない）
- `AnnotateCanvasView`（NSView）: マウスイベント → アイテム生成・編集。座標は**ポイント**
- `AnnotateRenderer`: `switch item.toolType` で CGContext に描画。エクスポート時は
  ポイント→ピクセルの `ctx.scaleBy(x: scale, y: scale)` を忘れない（Retina ずれの定番バグ）

### 6. ブランドプリセット（実装: `SharedModels/BrandPreset.swift` + `Utilities/BrandPresetStore.swift`）

- モデル: `BrandPreset`（`logoImageData: Data?` — CLAUDE.md の旧名 `logoImage` ではない）
- 永続化: `~/Library/Application Support/Clicher/presets/` に JSON、ロゴは `{presetId}.logo.png`
- `.clipreset` 形式でインポート/エクスポート（`BrandPresetStore`）
- 適用ポイント: Annotate のデフォルト色、`WatermarkRenderer` のロゴ合成、`BrandPresetSettingsView` の CRUD

### 7. 配布（実装: `Scripts/` + `Distribution/`）

- `Scripts/build-release.sh`: ビルド + 署名 + Notarization + DMG
- `Scripts/create-release.sh`: バージョンバンプ → GitHub Release → Homebrew tap 更新（`/release` スキルが使用）
- `Scripts/generate-appcast.sh`: Sparkle appcast 生成
- `Distribution/homebrew-cask/clicher.rb`: tap 用テンプレート（tap: `naoki-mrmt/homebrew-clicher`）
- **シークレット（APP_PASSWORD 等）はスクリプトにもコメントにも書かない。** `.env`（gitignore 済み）から渡す

## テスト方針

Swift Testing を使用（`@Suite` / `@Test` / `#expect`）。XCTest はパッケージテストでは禁止。
**例外**: `ClicherUITests/` の XCUITest のみ XCTest（Swift Testing は UI テスト非対応）。

- CaptureEngine: `ScreenCaptureServiceProtocol` 経由でモック注入。実キャプチャを発火させるテストを書かない
- AnnotateEngine: ドキュメントの状態遷移 + 描画結果の検証
- SharedModels / Utilities: モデル・永続化のユニットテスト（実ユーザーディレクトリではなく temp dir + `defer` cleanup）
- 列挙テストは `@Test(arguments: X.allCases)` のパラメータ化で書く

## 実装時のチェックリスト

新しいアノテーションツールを追加する時:

1. `AnnotationToolType`（SharedModels）にケースを追加（`label` / `systemImage` も）
2. `AnnotateCanvasView` のマウスハンドリングに挙動を追加
3. `AnnotateRenderer` の `switch item.toolType` に描画を追加
4. ツールバー UI（`InlineAnnotateOverlay` / `AnnotateEditorView`）にボタンを追加
5. Undo/Redo（スナップショットタイミング）を確認
6. ブランドプリセットのデフォルト色が反映されることを確認
7. Swift Testing でテストを追加

新しいキャプチャモードを追加する時:

1. `CaptureMode`（SharedModels）にケースを追加
2. `CaptureCoordinator` にフローを実装（**全終了経路で `isCapturing` リセットを確認**）
3. `ModeTabBarView`（InlineAnnotateOverlay 内）と `MenuBarView` に追加
4. `QuickAccessOverlay` への遷移を確認
5. マルチディスプレイ（座標反転・スケール係数）で動作確認
