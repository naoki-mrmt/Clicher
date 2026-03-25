# コミットメッセージ規約

## フォーマット
<type>(<scope>): <description>

## type 一覧
| type | 用途 |
|---|---|
| feat | 新機能 |
| improve | 既存機能の改善 |
| fix | バグ修正 |
| refactor | リファクタリング |
| docs | ドキュメント |
| chore | メンテナンス |
| test | テスト |

## scope（任意）
| scope | 用途 |
|---|---|
| capture | キャプチャエンジン（ScreenCaptureKit 関連） |
| annotate | アノテーションエンジン（描画・編集関連） |
| overlay | オーバーレイUI（HUD・QuickAccess・メニューバー） |
| models | 共有モデル（SharedModels パッケージ） |
| utils | ユーティリティ（設定・権限・ホットキー・エクスポート） |
| app | App ターゲット（ClicherApp・AppDelegate） |
| ui | UI 全般 |
| config | 設定ファイル・ビルド設定 |
| skill | スキル定義関連 |

## ルール
- description は小文字開始、末尾ピリオドなし
- 命令形で記述（add, fix, update, remove）
- 1行目は72文字以内
- 必要に応じて空行を挟んで本文を追加

## 例
feat(capture): add area selection overlay with size label
feat(annotate): implement undo/redo with 50-step stack limit
feat(overlay): add quick access overlay with auto-close
improve(utils): make image exporter support jpeg quality setting
fix(capture): correct coordinate conversion for retina displays
refactor(models): split AppState into separate enum files
test(annotate): add AnnotateDocument undo/redo tests
chore(config): update Package.swift dependencies
