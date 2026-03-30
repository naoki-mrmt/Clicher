# Clicher

macOS 用のスクリーンショット & アノテーションアプリ。CleanShot X 相当の機能を SwiftUI + AppKit でネイティブ実装。

## 機能

### キャプチャ
- **エリアキャプチャ** — ドラッグで範囲選択、ピクセルサイズ表示
- **ウィンドウキャプチャ** — ホバーでハイライト、クリックで選択
- **フルスクリーン** — ディスプレイ全体をキャプチャ
- **スクロールキャプチャ** — 複数フレームを自動スティッチング
- **OCR テキスト認識** — 日本語/英語対応、QR コード検出
- **画面録画** — MP4 (H.264)、システム音声/マイク対応、GIF 変換

### 編集
- **アノテーション** — 矢印、矩形、楕円、テキスト、モザイク、ハイライト、カウンター、ペンシル、クロップ
- **背景ツール** — グラデーション/単色背景、パディング、角丸、シャドウ
- **SNS プリセット** — Twitter、Instagram、OG Image サイズに自動リサイズ
- **動画エディタ** — トリム、品質変更、GIF 変換

### ブランド管理
- **ブランドプリセット** — カラー/ロゴ/フォント管理
- **ウォーターマーク** — エクスポート時にロゴを自動挿入
- **.clipreset 共有** — チーム間でプリセットをインポート/エクスポート

### ユーティリティ
- **フローティングスクリーンショット** — ピン留め表示、不透明度調整、クリックスルー
- **キャプチャ履歴** — サムネイル一覧、再編集
- **画像結合** — 横/縦結合、回転、反転
- **セルフタイマー** — 3/5/10 秒カウントダウン

## インストール

### Homebrew (推奨)

```bash
brew tap naoki-mrmt/clicher
brew install --cask clicher
```

### DMG から直接インストール

1. [Releases](https://github.com/naoki-mrmt/Clicher/releases) から最新の `.dmg` をダウンロード
2. DMG を開いて `Clicher.app` を `/Applications` にドラッグ
3. 初回起動時に権限設定ガイドが表示されます

### ソースからビルド

```bash
git clone https://github.com/naoki-mrmt/Clicher.git
cd Clicher
xcodebuild -scheme Clicher -configuration Release build
```

## 使い方

### 基本操作

**`Cmd+Shift+A`** でキャプチャ HUD を表示。数字キーでモード選択:

| キー | モード |
|------|--------|
| `1` | エリア |
| `2` | ウィンドウ |
| `3` | フルスクリーン |
| `4` | スクロール |
| `5` | OCR |
| `6` | 録画 |

キャプチャ後に Quick Access Overlay が表示されます:
- **保存** — 指定フォルダに保存
- **コピー** — クリップボードにコピー
- **編集** — アノテーションエディタを開く
- **ピン留め** — フローティングウィンドウで常時表示

### 権限設定

初回起動時に以下の権限が必要です:

| 権限 | 用途 | 設定方法 |
|------|------|---------|
| **Screen Recording** | 画面キャプチャ | システム設定 > プライバシーとセキュリティ > 画面収録 |
| **Accessibility** | グローバルホットキー | システム設定 > プライバシーとセキュリティ > アクセシビリティ |

権限を変更したらアプリを再起動してください。

## 技術スタック

- **Swift 6** (strict concurrency)
- **SwiftUI + AppKit** (メニューバー・オーバーレイは AppKit)
- **ScreenCaptureKit** (macOS 14+)
- **Vision Framework** (OCR)
- **AVFoundation** (録画・動画編集)
- **SPM マルチモジュール構成**

### パッケージ構成

```
Packages/
├── SharedModels      # 共通型（CaptureMode, BrandPreset 等）
├── Utilities         # 設定、権限、エクスポート、履歴
├── CaptureEngine     # キャプチャ、OCR、録画、スクロール
├── AnnotateEngine    # アノテーション、背景ツール
└── OverlayUI         # HUD、QuickAccess、設定画面
```

## 動作環境

- **macOS 14 Sonoma** 以降
- Apple Silicon / Intel 対応

## ライセンス

MIT License

## 開発

```bash
# テスト実行
swift test --package-path Packages/SharedModels
swift test --package-path Packages/Utilities
swift test --package-path Packages/CaptureEngine
swift test --package-path Packages/AnnotateEngine
swift test --package-path Packages/OverlayUI

# E2E テスト
xcodebuild test -scheme Clicher -configuration Debug -destination 'platform=macOS' -only-testing:ClicherTests

# リリースビルド
./Scripts/build-release.sh --skip-notarize
```
