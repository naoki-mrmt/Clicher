# /ship — Ship ワークフロー

Clicher (macOS スクリーンショット & アノテーションアプリ) 向けの自動シップフロー。
テスト → コミット → PR 作成を一気通貫で行う。

## 原則

`/ship` と言われたら実行する。非対話型で自動化。

### 停止するケース
- main ブランチ上にいる場合（中止）
- マージコンフリクトが自動解決できない場合
- テスト失敗

### 停止しないケース
- 未コミットの変更（自動的に含める）
- コミットメッセージの確認（自動生成）

## 参照リソース

- `_shared/git/branch-rules.md` — ブランチ命名規約
- `_shared/git/commit-rules.md` — コミットメッセージ規約（Conventional Commits）
- `_shared/git/pr-template.md` — PR テンプレート

## Step 0: ベースブランチ検出

1. `gh pr view --json baseRefName -q .baseRefName` で既存 PR のベースを確認
2. なければ `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`
3. 両方失敗したら `main` をフォールバック

## Step 1: プリフライト

1. 現在のブランチを確認（main なら中止）
2. `git status` で変更を確認
3. `git diff <base>...HEAD --stat` と `git log <base>..HEAD --oneline` で変更内容を把握

**ブランチがない場合:**
`_shared/git/branch-rules.md` に従いブランチを作成する:
- フォーマット: `feature/<name>`
- `git checkout -b <branch-name>`

## Step 2: ベースブランチのマージ

```bash
git fetch origin <base> && git merge origin/<base> --no-edit
```

コンフリクトがあれば停止して表示。

## Step 3: テスト実行

SPM パッケージのテストを実行する:

```bash
# 全パッケージのテスト
swift test --package-path Packages/SharedModels
swift test --package-path Packages/Utilities
swift test --package-path Packages/CaptureEngine
swift test --package-path Packages/AnnotateEngine
swift test --package-path Packages/OverlayUI
```

変更範囲に応じて必要なパッケージのみテストしてもよい:
- `Packages/SharedModels/` に変更 → 全パッケージをテスト（他が依存しているため）
- `Packages/Utilities/` に変更 → Utilities + 依存先（CaptureEngine, AnnotateEngine, OverlayUI）をテスト
- `Packages/CaptureEngine/` に変更 → CaptureEngine のみ
- `Packages/AnnotateEngine/` に変更 → AnnotateEngine のみ
- `Packages/OverlayUI/` に変更 → OverlayUI のみ
- `Clicher/` (App) に変更 → xcodebuild でビルド確認

全体ビルド確認:
```bash
xcodebuild -scheme Clicher -configuration Debug build
```

テスト失敗時は停止。

## Step 4: コミット

1. 変更を分析し論理的なコミットに分割する
2. `_shared/git/commit-rules.md` に従い Conventional Commits 形式でメッセージを生成する
3. パッケージごとに分けてコミットする（可能な場合）

## Step 5: プッシュ

```bash
git push -u origin <branch-name>
```

## Step 6: PR 作成

`_shared/git/pr-template.md` に従い PR を作成する。

```bash
gh pr create --base <base> --title "<type>: <概要>" --body "..."
```

**PR は日本語で作成する。** `_shared/git/pr-template.md` のテンプレートに従う。

PR 本文に含めるもの:
- ## 概要
- ## 変更内容（箇条書き）
- ## テスト（テスト結果・チェック項目）

**最後に PR URL を出力する。**

## Examples

### Example 1: 通常のシップ
```
/ship
```
→ テスト実行 → コミット → PR 作成

### Example 2: 機能実装後のシップ
```
/ship
```
→ SPM パッケージテスト → xcodebuild → コミット → PR 作成

## トラブルシューティング

### main ブランチ上で実行してしまった
原因: feature ブランチに切り替え忘れ
対処: `git checkout -b feature/xxx` でブランチを作成してからリトライ

### マージコンフリクト
原因: ベースブランチとの差分が大きい
対処: 手動でコンフリクトを解決し、再度 `/ship` を実行

### テスト失敗で停止
原因: コード変更にテストが追いついていない
対処: 失敗テストを修正してから再実行。`/ship` は自動リトライしない

### xcodebuild が失敗する
原因: パッケージ依存の不整合、pbxproj の問題
対処: Xcode でプロジェクトを開いて Resolve Package Versions を実行
