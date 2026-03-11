# Clicher — macOS Screenshot & Annotation App 実装計画

## アプリ名候補

| 名前 | コンセプト | 備考 |
|------|-----------|------|
| **Clicher** | cliché（写真・スナップショット）の動詞形。フランス語で「パシャッと撮る」| 決定 |
| **Kappture** | Capture の日本語的遊び + ture | 独自性あり、商標衝突しにくい |
| **ShotCraft** | Shot + Craft（職人的な仕上げ） | プロ向け感。CleanShotとの差別化 |
| **Picter** | Picture + Editor の造語 | シンプルで覚えやすい |
| **Mado** | 窓（まど）= Window | 日本語由来、macOS的。海外展開もユニーク |

> 以下では仮に **Clicher** で記述する。名前が決まったら一括置換。

---

## 技術スタック

| レイヤー | 技術 | 理由 |
|---------|------|------|
| UI | SwiftUI + AppKit | メニューバー・オーバーレイ・グローバルホットキーにAppKit必須 |
| キャプチャ | ScreenCaptureKit (macOS 14+) | Apple推奨。CGWindowListCreateImage は deprecated |
| 画像編集 | CoreGraphics + CoreImage | ネイティブパフォーマンス。Annotateレイヤーは独自実装 |
| OCR | Vision Framework | オンデバイス処理、プライバシー重視 |
| 録画 | AVFoundation + ScreenCaptureKit | MP4/GIF出力 |
| 配布 | Homebrew Cask + Sparkle | `brew install --cask clicher` |
| CI/CD | GitHub Actions + Xcode Cloud | ビルド・署名・Notarization自動化 |
| パッケージ管理 | Swift Package Manager (SPM) | マルチモジュール構成 |
| 最小OS | macOS 14 (Sonoma) | ScreenCaptureKit Screenshot APIがmacOS 14で安定 |

---

## アーキテクチャ概要

```
Clicher/
├── App/                          # アプリエントリポイント
│   ├── ClicherApp.swift        # @main, メニューバー設定
│   └── AppDelegate.swift         # AppKit統合、グローバルホットキー
│
├── Packages/                     # SPMマルチモジュール
│   ├── CaptureEngine/            # スクリーンキャプチャコア
│   │   ├── ScreenCaptureService  # ScreenCaptureKit ラッパー
│   │   ├── CaptureMode           # Area/Window/Fullscreen/Scroll
│   │   └── CaptureCoordinator    # キャプチャフロー管理
│   │
│   ├── AnnotateEngine/           # 画像編集・アノテーション
│   │   ├── AnnotateCanvas        # メイン描画キャンバス
│   │   ├── Tools/                # 各ツール（矢印・矩形・テキスト等）
│   │   ├── AnnotateDocument      # Undo/Redo、レイヤー管理
│   │   └── Export                # PNG/JPEG/ClipBoard出力
│   │
│   ├── OverlayUI/                # Quick Access Overlay
│   │   ├── OverlayWindow         # フローティングウィンドウ
│   │   └── OverlayActions        # Save/Copy/Edit/D&D
│   │
│   ├── SharedModels/             # 共通型定義
│   │   ├── CaptureResult         # キャプチャ結果
│   │   ├── AnnotationModel       # アノテーションデータ
│   │   └── AppSettings           # 設定モデル
│   │
│   └── Utilities/                # 共通ユーティリティ
│       ├── HotkeyManager         # グローバルホットキー管理
│       ├── PermissionManager     # Screen Recording権限
│       └── FileManager+Ext      # ファイル保存ヘルパー
│
├── Resources/                    # アセット
│   ├── Assets.xcassets
│   └── Backgrounds/              # Background Tool用プリセット
│
└── Tests/
    ├── CaptureEngineTests/
    └── AnnotateEngineTests/
```

### 設計原則

1. **モジュール分離**: CaptureEngine / AnnotateEngine / OverlayUI をSPMパッケージとして独立
2. **Protocol指向**: キャプチャ・ツール・エクスポートをProtocolで抽象化し、テスト容易性を確保
3. **@Observable**: macOS 14以降の Observation フレームワーク使用
4. **AppKit Bridge**: メニューバー・オーバーレイ・ホットキーなどSwiftUIでカバーできない部分はAppKitで実装し、SwiftUI側からはラッパー経由で利用

---

## Phase 1: MVP — スクリーンショット撮影 + 編集コア

**目標**: 撮影→編集→保存/コピーの基本フローを完成させる

### 1.1 プロジェクトセットアップ（Sprint 0）

| タスク | 詳細 |
|--------|------|
| Xcodeプロジェクト作成 | macOS App, SwiftUI lifecycle, SPMマルチモジュール |
| SPMパッケージ構成 | CaptureEngine / AnnotateEngine / OverlayUI / SharedModels / Utilities |
| CI基盤 | GitHub Actions で build & test |
| コード署名 | Developer ID Application証明書、Notarization設定 |
| 権限設定 | Entitlements: Screen Recording, Accessibility |

### 1.2 メニューバーアプリ基盤

| タスク | 詳細 |
|--------|------|
| MenuBarExtra | SwiftUI MenuBarExtra + NSStatusItem fallback |
| メニュー構成 | Capture Area / Window / Fullscreen、Preferences、Quit |
| グローバルホットキー | `CGEvent.tapCreate` ベースの自前実装 |
| 権限チェック | Screen Recording権限の確認・誘導フロー |
| ログイン時起動 | `SMAppService` (macOS 13+) |

### 1.3 スクリーンキャプチャ

| タスク | 詳細 |
|--------|------|
| **エリアキャプチャ** | 透明オーバーレイウィンドウ、マウスドラッグで範囲選択 |
| クロスヘア表示 | マウス位置に十字線 + 座標表示 |
| マグニファイア | 選択ポイント付近のズームルーペ |
| サイズ表示 | 選択中のピクセルサイズをリアルタイム表示 |
| **ウィンドウキャプチャ** | `SCShareableContent`でウィンドウ一覧取得→ホバーでハイライト→クリックで撮影 |
| ウィンドウ背景 | 影あり/なし、透明背景、カスタムカラー/画像背景 |
| **フルスクリーン** | `SCDisplay`からキャプチャ。マルチモニター対応 |
| 画像出力 | `CGImage` → `NSImage` → PNG/JPEG保存 or クリップボード |

### 1.4 Quick Access Overlay

| タスク | 詳細 |
|--------|------|
| フローティングウィンドウ | `NSPanel` level: .floating、角丸サムネイル表示 |
| アクションボタン | Save / Copy / Edit（Annotateへ遷移）/ Close |
| ドラッグ&ドロップ | サムネイルをD&Dで他アプリへ直接渡し |
| 自動クローズ | 設定可能なタイムアウト |
| スワイプジェスチャ | 上スワイプ→保存、下スワイプ→削除 |
| 位置カスタマイズ | 画面四隅のどこに表示するか設定 |

### 1.5 Annotate（画像編集エディタ）

| タスク | 詳細 |
|--------|------|
| **キャンバス基盤** | NSView + Core Graphics描画。ズーム/パン対応 |
| **ツールバー** | 左側にツールパレット、上部にツールオプション |
| **矢印ツール** | 4スタイル（直線・カーブ・太・細）、色/太さ変更 |
| **矩形ツール** | 枠線のみ / 塗りつぶし、角丸オプション |
| **楕円ツール** | 矩形と同等オプション |
| **線ツール** | 直線描画、太さ/色 |
| **テキストツール** | 7種プリセットスタイル、フォント/サイズ/色変更、インライン編集 |
| **ピクセル化（モザイク）** | 選択範囲をブロック化。セキュリティ用ランダム化 |
| **ブラー** | ガウスブラー。Smooth/Secureモード |
| **ハイライター** | 半透明カラーオーバーレイ |
| **カウンター** | ナンバリングバッジ（チュートリアル用手順表示） |
| **ペンシル** | フリーハンド描画、自動スムージング |
| **クロップ** | アスペクト比指定、エッジスナップ |
| **スポットライト** | 選択範囲以外を暗くして強調 |
| **Undo/Redo** | コマンドパターンで実装。Cmd+Z / Cmd+Shift+Z |
| **カラーピッカー** | よく使う色のプリセット + カスタムカラー保存 |
| **エクスポート** | PNG / JPEG / クリップボード / ファイル保存 |

### 1.6 設定画面

| タスク | 詳細 |
|--------|------|
| ホットキー設定 | カスタマイズ可能なキーバインド |
| 保存先設定 | デフォルトの保存ディレクトリ |
| ファイル命名規則 | 日時ベース or カスタムパターン |
| 画質設定 | Retina対応（1x/2x） |
| Overlay設定 | 位置、自動クローズ時間、サイズ |

---

## Phase 2: 差別化機能

**目標**: CleanShot Xのキラー機能を実装し、実用レベルへ引き上げ

### 2.1 スクロールキャプチャ

| タスク | 詳細 |
|--------|------|
| 範囲選択 | Phase 1のエリア選択UIを流用 |
| 自動スクロール検知 | `CGEvent` でスクロールイベントを監視 |
| フレームスティッチング | 複数フレームの差分検出→縦/横方向に結合 |
| 進行状況UI | スクロール中のプログレス表示 |
| 水平スクロール対応 | 横方向のスクロールキャプチャ |

### 2.2 OCR（テキスト認識）

| タスク | 詳細 |
|--------|------|
| 範囲選択→テキスト抽出 | `VNRecognizeTextRequest` でオンデバイスOCR |
| クリップボードコピー | 認識結果を即座にクリップボードへ |
| 言語設定 | 日本語/英語/他言語のサポート |
| QRコード読み取り | `VNDetectBarcodesRequest` で検出 |

### 2.3 Background Tool

| タスク | 詳細 |
|--------|------|
| 背景プリセット | 10種以上のグラデーション/パターン |
| カスタム背景 | ユーザー画像、単色 |
| パディング調整 | 上下左右の余白コントロール |
| アスペクト比 | 16:9, 4:3, 1:1, カスタム |
| Auto Balance | コンテンツ位置の自動調整 |
| SNS最適化 | Twitter/Instagram等のサイズプリセット |

### 2.4 Floating Screenshots

| タスク | 詳細 |
|--------|------|
| ピン留め | 任意のスクショを最前面に固定表示 |
| サイズ・不透明度調整 | ドラッグでリサイズ、スライダーで透過度 |
| ロックモード | 下のアプリを操作可能にするパススルー |
| 矢印キー移動 | ピクセル単位の位置微調整 |

### 2.5 ブランドプリセット（Brand Preset）

| タスク | 詳細 |
|--------|------|
| **プリセット作成UI** | ブランドカラー（プライマリ/セカンダリ/アクセント）、ロゴ画像、フォント設定をまとめて保存 |
| **プリセット管理** | 複数プリセットの作成・編集・削除・並び替え。クライアント別に管理可能 |
| **デフォルトプリセット設定** | 1つをデフォルトに指定 → 全キャプチャに自動適用 |
| **Annotate自動適用** | プリセットのブランドカラーをAnnotateツールのデフォルト色に反映（矢印・矩形・テキスト等） |
| **Background Tool連携** | ブランドカラーのグラデーション背景を自動生成。ロゴの自動ウォーターマーク配置 |
| **テキストスタイル連携** | ブランドフォント・サイズをテキストツールのデフォルトに |
| **ウォーターマーク** | ロゴ画像を指定位置（四隅/中央）に自動挿入。不透明度調整可能 |
| **エクスポートテンプレート** | ブランドプリセットに紐づいた出力設定（ファイル形式・品質・命名規則） |
| **ワンクリック適用** | Quick Access Overlay からプリセット切り替え可能 |
| **インポート/エクスポート** | `.clipreset` JSON形式でチーム共有 |

**ユースケース例**:
1. クライアントA用プリセットを作成（ブランドカラー: #FF6B35, ロゴ: logo-a.png）
2. デフォルトプリセットに設定
3. 以降のキャプチャは全てクライアントAのブランドカラーで統一
4. 別のクライアント作業時はプリセットを切り替えるだけ

### 2.6 追加キャプチャ機能

| タスク | 詳細 |
|--------|------|
| 画面フリーズ | 撮影前にスクリーンを静止（ホバー状態キャプチャ等） |
| デスクトップアイコン非表示 | 撮影時にFinderアイコンを一時的に隠す |
| セルフタイマー | 3秒/5秒/10秒のカウントダウン後にキャプチャ |
| All-In-Oneモード | 1つのショートカットで全キャプチャモードにアクセス |

---

## Phase 3: 拡張機能

**目標**: 録画・クラウド・履歴管理で総合ツールへ

### 3.1 画面録画

| タスク | 詳細 |
|--------|------|
| 録画エンジン | ScreenCaptureKit Stream → AVAssetWriter |
| エリア/ウィンドウ/全画面 | Phase 1のキャプチャモードを流用 |
| MP4出力 | H.264エンコード |
| GIF出力 | フレーム抽出→GIF生成（最適化付き） |
| マイク録音 | AVAudioEngine でマイク入力キャプチャ |
| システム音声 | ScreenCaptureKitのオーディオストリーム |
| クリック表示 | マウスクリックを視覚的にハイライト |
| キーストローク表示 | 押されたキーをオーバーレイ表示 |
| ウェブカメラ | AVCaptureDevice でPiP表示 |
| Do Not Disturb | 録画中に自動で通知を抑制 |

### 3.2 動画エディタ

| タスク | 詳細 |
|--------|------|
| トリム | 開始/終了点の設定 |
| 品質変更 | 解像度・FPS・ビットレート調整 |
| 音声調整 | ボリューム・ミュート・ステレオ→モノ変換 |
| プレビュー | インラインプレイヤー |

### 3.3 クラウド連携

| タスク | 詳細 |
|--------|------|
| アップロード | 自前サーバー or S3互換ストレージ |
| 共有リンク生成 | ワンクリックでURLをクリップボードへ |
| パスワード保護 | リンクにパスワード設定 |
| 自動削除 | 一定期間後に自動消滅 |
| チーム管理 | 組織でのメディア共有 |

### 3.4 キャプチャ履歴

| タスク | 詳細 |
|--------|------|
| 履歴一覧 | 最大1ヶ月分のキャプチャをサムネイル表示 |
| フィルター | 種類別（スクショ/録画/GIF）で絞り込み |
| 再アノテート | 履歴から再編集 |
| 検索 | ファイル名・日付での検索 |

### 3.5 その他

| タスク | 詳細 |
|--------|------|
| 複数画像結合 | D&Dで複数スクショを1枚に合成 |
| 独自ファイル形式 | `.clicher` 形式で再編集可能な状態保存 |
| 画像の回転/反転 | Annotate内で回転・ミラー |
| ウィンドウ背景の後編集 | 撮影後に背景変更・削除 |

---

## Phase 4: 配布・運用

### 4.1 配布基盤

| タスク | 詳細 |
|--------|------|
| Sparkle統合 | 自動アップデートフレームワーク |
| Homebrew Cask | formulaの作成・メンテナンス |
| Notarization | `notarytool` でApple公証 |
| DMGインストーラー | `create-dmg` でカスタムDMG生成 |
| ランディングページ | Astro + Cloudflare Pages |

### 4.2 品質管理

| タスク | 詳細 |
|--------|------|
| ユニットテスト | CaptureEngine / AnnotateEngine の核心ロジック |
| UIテスト | XCUITest でキャプチャ→編集フロー |
| パフォーマンス | Instruments でメモリ/CPU プロファイリング |
| クラッシュ監視 | Sentry or 自前のクラッシュレポーティング |

---

## 想定スケジュール（目安）

| Phase | 期間 | マイルストーン |
|-------|------|--------------|
| Phase 1 | 4-6週 | MVP: 撮影→編集→保存が動く |
| Phase 2 | 4-6週 | スクロール・OCR・Background完成 |
| Phase 3 | 6-8週 | 録画・クラウド・履歴 |
| Phase 4 | 2-3週 | Homebrew配布、ランディングページ |

> Claude Codeで並行開発する前提。実際のペースはCCのトークン消費やAPI制限に依存。
