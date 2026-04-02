# /release スキル — Clicher リリース自動化

## 概要

バージョンバンプからHomebrew tap更新まで、リリースの全ステップを自動実行する。

## 使い方

```
/release 0.3.0
```

引数でバージョンを指定する。引数がない場合はパッチバージョンを自動インクリメントする。

## 実行手順

### 1. バージョン決定

- 引数があればそのバージョンを使用
- 引数がなければ `project.pbxproj` の `MARKETING_VERSION` を読み取り、パッチバージョンを +1

### 2. バージョンバンプ

```bash
# project.pbxproj の MARKETING_VERSION を更新
sed -i '' "s/MARKETING_VERSION = .*;/MARKETING_VERSION = <VERSION>;/" Clicher.xcodeproj/project.pbxproj
```

Editツールで `MARKETING_VERSION` を `replace_all: true` で一括置換する。

### 3. ビルド確認

```bash
xcodebuild -scheme Clicher -configuration Debug build 2>&1 | tail -5
```

**BUILD SUCCEEDED** を確認。失敗したらリリースを中止してエラーを報告。

### 4. コミット & Push

```bash
git add -A
git commit -m "chore(config): bump version to <VERSION>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
git push origin main
```

- `plan-inline-annotate.md` など不要ファイルは `git reset HEAD` で除外
- コミットメッセージは既存のスタイル (`chore(config): bump version to X.Y.Z`) に合わせる

### 5. リリーススクリプト実行

```bash
source .env && APP_PASSWORD="${APP_PASSWORD}" ./Scripts/create-release.sh <VERSION>
```

このスクリプトが以下を自動実行:
1. リリースビルド (Developer ID 署名)
2. DMG 作成
3. Notarization 送信 & Staple
4. git tag `v<VERSION>` 作成 & push
5. GitHub Release 作成 (DMG アップロード)
6. Homebrew tap (`naoki-mrmt/homebrew-clicher`) 更新

### 6. 完了報告

リリース完了後、以下を表示:
- GitHub Release URL
- SHA-256
- インストールコマンド: `brew uninstall --cask clicher; brew untap naoki-mrmt/clicher; brew tap naoki-mrmt/clicher && brew install --cask clicher`

## 注意事項

- `.env` に `APP_PASSWORD` が設定されていること（Notarization用）
- `Scripts/create-release.sh` はタイムアウト 10 分（600000ms）で実行
- リリーススクリプトは Homebrew tap の PR も自動作成・マージする
