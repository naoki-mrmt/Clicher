# Clicher 実装計画 — SPMモジュール化 + テスト追加 + Phase 2以降

## Context

Phase 1 (1.2〜1.7) のコード実装が完了したが、以下が未対応:
- SPMマルチモジュール化（CLAUDE.md の設計に従う）
- テストが全く書かれていない（TDD で進めるべきだった）
- Phase 2 以降の計画整理

**方針**: 今後はテストを先に書いてから実装する（TDD）。

---

## 1. SPMモジュール化

### 依存グラフ

```
SharedModels (leaf — 依存なし)
    ↑
Utilities (← SharedModels)
    ↑
CaptureEngine (← SharedModels, Utilities)
AnnotateEngine (← SharedModels のみ)
OverlayUI (← SharedModels, Utilities)
    ↑
App (← ALL)
```

### パッケージ構成と移動ファイル

#### SharedModels（共通型）
| 移動元 | 移動先 | 備考 |
|--------|--------|------|
| AppState.swift → CaptureMode enum | `CaptureMode.swift` | 分割 |
| AppState.swift → TimerDelay enum | `TimerDelay.swift` | 分割 |
| AppState.swift → AppState class | `AppState.swift` | 分割 |
| Capture/CaptureResult.swift | `CaptureResult.swift` | そのまま |
| AnnotationItem.swift → AnnotationToolType | `AnnotationToolType.swift` | 分割 |
| AnnotationItem.swift → AnnotationStyle | `AnnotationStyle.swift` | 分割 |
| AnnotationItem.swift → AnnotationItem class | `AnnotationItem.swift` | 分割 |
| ImageExporter.swift → ImageFormat enum | `ImageFormat.swift` | 分割 |
| AppSettings.swift → FileNamePattern enum | `FileNamePattern.swift` | 分割 |
| AppSettings.swift → OverlayPosition enum | `OverlayPosition.swift` | 分割 |

#### Utilities（横断サービス）
| 移動元 | 移動先 |
|--------|--------|
| Services/HotkeyManager.swift | `HotkeyManager.swift` |
| Services/PermissionManager.swift | `PermissionManager.swift` |
| Services/LoginItemManager.swift | `LoginItemManager.swift` |
| Services/AppSettings.swift (class部分) | `AppSettings.swift` |
| Capture/ImageExporter.swift (enum部分) | `ImageExporter.swift` |
| Services/Logger+Clicher.swift | `Logger+Clicher.swift` |

#### CaptureEngine（キャプチャコア）
| 移動元 | 移動先 |
|--------|--------|
| Capture/ScreenCaptureService.swift | `ScreenCaptureService.swift` |
| Capture/CaptureCoordinator.swift | `CaptureCoordinator.swift` |
| Capture/AreaSelectionOverlay.swift | `AreaSelectionOverlay.swift` |
| Capture/WindowSelectionOverlay.swift | `WindowSelectionOverlay.swift` |

#### AnnotateEngine（画像編集）
| 移動元 | 移動先 |
|--------|--------|
| Annotate/AnnotateDocument.swift | `AnnotateDocument.swift` |
| Annotate/AnnotateRenderer.swift | `AnnotateRenderer.swift` |
| Annotate/AnnotateCanvasView.swift | `AnnotateCanvasView.swift` |
| Annotate/AnnotateEditorView.swift | `AnnotateEditorView.swift` |
| Annotate/AnnotateWindow.swift | `AnnotateWindow.swift` |

#### OverlayUI（UI コンポーネント）
| 移動元 | 移動先 |
|--------|--------|
| Views/CaptureHUDView.swift | `CaptureHUDView.swift` |
| Views/CaptureHUDWindow.swift | `CaptureHUDWindow.swift` |
| Views/QuickAccessOverlay.swift | `QuickAccessOverlay.swift` |
| Views/QuickAccessView.swift | `QuickAccessView.swift` |
| Views/MenuBarView.swift | `MenuBarView.swift` |
| Views/SettingsView.swift | `SettingsView.swift` |
| Views/PermissionGuideView.swift | `PermissionGuideView.swift` |

#### App（薄いシェル — 残留ファイル）
- `ClicherApp.swift` — 全パッケージ import + ワイヤリング
- `AppDelegate.swift` — AppKit 統合
- `Assets.xcassets`

### 主要な変更点
- 全公開型に `public` を付与（init含む）
- SPM パッケージは `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` を継承しないため、`@Observable` クラスに明示的に `@MainActor` を付与
- 各 Package.swift で `.swiftLanguageMode(.v6)` を指定
- ローカル SPM パッケージとして Xcode プロジェクトに追加（workspace 不要）

---

## 2. テスト追加（TDD — テストを先に書く）

全パッケージに Swift Testing でテストを書く。

### SharedModelsTests
- CaptureMode: availableModes, ラベル/画像の存在
- AnnotationItem: boundingRect 計算、pencil のポイント配列
- AnnotationStyle: デフォルト値
- AppState: 初期値

### UtilitiesTests
- ImageExporter: ファイル保存成功、ファイル名フォーマット
- AppSettings: デフォルト値、UserDefaults 永続化

### CaptureEngineTests
- CaptureCoordinator: 初期状態、モック注入（ScreenCaptureServiceProtocol）
- MockCaptureService を作成してテスト

### AnnotateEngineTests
- AnnotateDocument: add/undo/redo、スタック上限50、カウンター番号
- AnnotateRenderer: 空リスト描画、各ツール描画がクラッシュしない

### OverlayUITests
- 状態遷移の軽量テスト

---

## 3. 実行順序

1. **パッケージディレクトリ + Package.swift 作成**
2. **テストファイルを先に書く**（コンパイルは通らない）
3. **SharedModels 抽出** → テスト通す
4. **Utilities 抽出** → テスト通す
5. **CaptureEngine 抽出** → テスト通す
6. **AnnotateEngine 抽出** → テスト通す
7. **OverlayUI 抽出** → テスト通す
8. **App ターゲット更新** → 全体ビルド
9. **手動E2Eテスト**

---

## 4. Phase 2 以降のロードマップ

### Phase 2: 差別化機能（4-6週）
| 機能 | 概要 |
|------|------|
| 2.1 スクロールキャプチャ | CGEvent スクロール監視 + フレームスティッチング |
| 2.2 OCR | VNRecognizeTextRequest + QRコード検出 |
| 2.3 Background Tool | グラデーション/画像背景、パディング、SNSサイズプリセット |
| 2.4 Floating Screenshots | ピン留め表示、不透明度調整、パススルー |
| 2.5 ブランドプリセット | カラー/ロゴ/フォント管理、ウォーターマーク、.clipreset 共有 |
| 2.6 追加キャプチャ機能 | 画面フリーズ、デスクトップアイコン非表示、セルフタイマー |

**Phase 2 完了条件:**
- [ ] ブランドプリセットの作成・編集・削除が動作
- [ ] デフォルトプリセットがAnnotateツールに自動反映
- [ ] ロゴウォーターマークがエクスポート時に適用
- [ ] `.clipreset` のインポート/エクスポートが動作

### Phase 3: 拡張機能（6-8週）
| 機能 | 概要 |
|------|------|
| 3.1 画面録画 | ScreenCaptureKit Stream → MP4/GIF、マイク/システム音声 |
| 3.2 動画エディタ | トリム、品質変更、音声調整 |
| 3.3 クラウド連携 | アップロード、共有リンク、パスワード保護 |
| 3.4 キャプチャ履歴 | サムネイル一覧、フィルター、再編集 |
| 3.5 その他 | 複数画像結合、.clicher形式、回転/反転 |

### Phase 4: 配布・運用（2-3週）
| 機能 | 概要 |
|------|------|
| 4.1 配布基盤 | Sparkle、Homebrew Cask、Notarization、DMG |
| 4.2 品質管理 | Instruments プロファイリング、クラッシュ監視 |

---

## 5. 検証方法

### SPMモジュール化の検証
```bash
# 各パッケージ個別ビルド
swift build --package-path Packages/SharedModels
swift build --package-path Packages/Utilities
swift build --package-path Packages/CaptureEngine
swift build --package-path Packages/AnnotateEngine
swift build --package-path Packages/OverlayUI

# 各パッケージテスト
swift test --package-path Packages/SharedModels
swift test --package-path Packages/Utilities
swift test --package-path Packages/CaptureEngine
swift test --package-path Packages/AnnotateEngine
swift test --package-path Packages/OverlayUI

# 全体ビルド
xcodebuild -scheme Clicher -configuration Debug build

# 全体テスト
xcodebuild -scheme Clicher -configuration Debug test
```

### 手動E2E確認
1. メニューバーアイコンが表示される
2. ⌘⇧A でキャプチャHUDが表示/非表示
3. エリア/ウィンドウ/フルスクリーンキャプチャが動作
4. Quick Access Overlay でコピー/保存/編集が動作
5. Annotate で矢印/矩形/テキスト/モザイク/クロップ + Undo/Redo
6. 設定画面が開ける
