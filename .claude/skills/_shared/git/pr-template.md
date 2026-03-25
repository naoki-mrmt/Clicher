# PR テンプレート

## タイトル規約

`<type>: <概要>` 形式。日本語で記述する。

例:
- `feat: SPMモジュール化とテスト追加`
- `fix: Retina座標変換の不具合を修正`
- `improve: アノテーションツールのUndoスタック最適化`
- `refactor: SharedModelsから型を分離`
- `test: AnnotateDocumentのユニットテスト追加`

## 本文テンプレート

```markdown
## 概要
<!-- このPRで何をしたか1〜2文で -->

## 変更内容
<!-- 主な変更のサマリー。箇条書きで -->
-
-
-

## レビューポイント
<!-- レビュアーに特に見てほしい箇所 -->
-

## テスト
<!-- 変更範囲に応じてチェック項目を選択 -->

### Swift パッケージ（Packages/ に変更がある場合）
- [ ] 全パッケージテスト通過（`swift test --package-path Packages/<name>`）
- [ ] xcodebuild ビルド通過（`xcodebuild -scheme Clicher -configuration Debug build`）

### UI（OverlayUI/ または Clicher/ に変更がある場合）
- [ ] メニューバーアイコンが表示される
- [ ] ⌘⇧A でキャプチャHUDが表示/非表示
- [ ] エリア/ウィンドウ/フルスクリーンキャプチャが動作
- [ ] Quick Access Overlay でコピー/保存/編集が動作

### アノテーション（AnnotateEngine/ に変更がある場合）
- [ ] 矢印/矩形/テキスト/モザイク/クロップが動作
- [ ] Undo/Redo が動作
- [ ] エクスポートが正しく動作

### スキル・設定（.claude/ に変更がある場合）
- [ ] スキルのトリガーが正常に動作する
- [ ] INSTRUCTIONS.md の手順に矛盾がない
```
