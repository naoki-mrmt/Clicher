# ブランチ規約

## ブランチ構成

```
main              ← 本番。タグを打つ
feature/<name>    ← 機能開発（main から切って main に戻す）
release/<version> ← リリース準備（main にマージ）
hotfix/<name>     ← 緊急修正（main から切って main にマージ）
```

## 命名規約

| ブランチ | フォーマット | 例 |
|---------|------------|---|
| feature | `feature/<name>` | `feature/spm-modularize`, `feature/scroll-capture` |
| release | `release/<major>.<minor>.<patch>` | `release/1.0.0` |
| hotfix | `hotfix/<name>` | `hotfix/crash-on-retina` |

- 全て小文字
- 単語区切りはハイフン（-）
- name は簡潔に（2〜4単語）

## フロー

### 機能開発

```
main → feature/xxx → PR → main
```

1. `main` から `feature/xxx` を切る
2. 開発・コミット
3. `main` に向けて PR を作成
4. レビュー後マージ

### リリース

```
main → release/1.0.0 → （テスト・修正）→ main にマージ → タグ 1.0.0
```

1. `main` から `release/1.0.0` を切る
2. リリース準備（バグ修正のみ。新機能追加は禁止）
3. `main` にマージ
4. `main` にタグ `1.0.0` を打つ

### 緊急修正

```
main → hotfix/xxx → main にマージ → タグ 1.0.1
```

1. `main` から `hotfix/xxx` を切る
2. 修正・テスト
3. `main` にマージ
4. `main` にタグ `1.0.1` を打つ（patch を上げる）

## セマンティックバージョニング

### タグ命名

```
{major}.{minor}.{patch}
```

### バージョンアップ基準

| 種別 | 上げる番号 | 例 |
|------|----------|---|
| 破壊的変更 | major | 1.0.0 → 2.0.0 |
| 新機能追加（後方互換あり） | minor | 1.0.0 → 1.1.0 |
| バグ修正、改善、ドキュメント | patch | 1.0.0 → 1.0.1 |

### タグを打つタイミング

- release ブランチ: main にマージした後（minor or major）
- hotfix ブランチ: main にマージした後（patch）
- `git tag -a 1.0.0 -m "1.0.0"` で annotated tag を使用
