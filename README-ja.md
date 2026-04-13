<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-6.0-orange" alt="Swift">
  <img src="https://img.shields.io/github/v/release/naoki-mrmt/Clicher" alt="Release">
  <img src="https://img.shields.io/github/license/naoki-mrmt/Clicher" alt="License">
</p>

# Clicher

[English](./README.md) / 日本語

macOS のスクリーンショットツール。キャプチャ、編集、録画、OCR まで全部入り。

## できること

- **キャプチャ** — エリア選択 / ウィンドウ（クリック）/ フルスクリーン / セルフタイマー
- **OCR** — 日本語・英語のテキスト認識（結果パネルから選択コピー）、QR コード読み取り
- **録画** — MP4 書き出し、システム音声・マイクトグル、録画後の GIF 変換
- **編集** — 矢印、矩形、楕円、テキスト、モザイク、ハイライト、ペンシル、クロップ、カウンターなど
- **背景** — グラデーション / 単色、余白、角丸、影、SNS サイズ合わせ
- **ブランド** — カラー・ロゴ・フォントのプリセット管理、ウォーターマーク自動挿入、`.clipreset` 共有
- **フローティング** — スクショをデスクトップにピン留め、透過度・クリック貫通
- **動画編集** — トリム、画質変更
- **画像加工** — 結合（横 / 縦）、回転、反転

## インストール

### Homebrew

```bash
brew tap naoki-mrmt/clicher
brew install --cask clicher
```

### DMG

[Releases](https://github.com/naoki-mrmt/Clicher/releases) から `.dmg` を落として、`Clicher.app` を `/Applications` に入れる。

### ソースビルド

```bash
git clone https://github.com/naoki-mrmt/Clicher.git
cd Clicher
xcodebuild -scheme Clicher -configuration Release build
```

## 使い方

**`Cmd+Shift+A`** で選択オーバーレイが起動。2 種類の操作に対応:

- **ドラッグ** → エリアキャプチャ（モードタブを切り替えれば録画 / OCR にも）
- **ウィンドウをクリック** → そのウィンドウ全体をキャプチャ（ホバー中のウィンドウは青枠で表示）

選択オーバーレイ上部のタブでモード切替:

```
[ スクリーンショット ] [ 画面収録 ] [ テキストを認識 ]
```

撮影後は編集オーバーレイが出るので、注釈・保存・コピー・ピン留めが選べる。

OCR モードはテキスト全文を中央パネルに表示し、選択コピー & 「すべてコピー」ボタンに対応。

録画停止後は「保存 / コピー / GIF 化 / Finder で表示」の選択パネルが出る。

### 権限

初回起動時にこの 2 つを許可する。設定後はアプリ再起動。

| 権限 | 何に使う | 場所 |
|------|---------|------|
| Screen Recording | キャプチャ全般 | システム設定 → プライバシーとセキュリティ → 画面収録 |
| Accessibility | `Cmd+Shift+A` ホットキー | システム設定 → プライバシーとセキュリティ → アクセシビリティ |

## 構成

SPM マルチモジュール。Swift 6 strict concurrency。

```
Packages/
├── SharedModels     # 型定義
├── Utilities        # 設定、権限、エクスポート
├── CaptureEngine    # キャプチャ、OCR、録画
├── AnnotateEngine   # 描画、背景ツール
└── OverlayUI        # HUD、オーバーレイ、設定画面
```

SwiftUI + AppKit / ScreenCaptureKit / Vision / AVFoundation

## 動作環境

macOS 14 Sonoma 以降。Apple Silicon / Intel 両対応。

## 開発

```bash
# テスト
for pkg in SharedModels Utilities CaptureEngine AnnotateEngine OverlayUI; do
  swift test --package-path "Packages/$pkg"
done

# E2E
xcodebuild test -scheme Clicher -only-testing:ClicherTests

# リリースビルド
./Scripts/build-release.sh --skip-notarize
```

## コントリビュート

Fork → ブランチ切る → PR 出す。コミット規約は [commit-rules.md](.claude/skills/_shared/git/commit-rules.md) を参照。

## ライセンス

[MIT](LICENSE)
