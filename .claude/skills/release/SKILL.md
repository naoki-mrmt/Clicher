---
name: release
description: >-
  Clicher のリリース自動化スキル。バージョンバンプ → コミット → push → ビルド → Notarization → GitHub Release → Homebrew tap 更新を一気通貫で実行する。
  以下の場合に使用:
  (1)「/release 0.3.0」「リリースして」
  (2)「バージョン上げてリリース」
  (3)「v0.3.0 出して」
metadata:
  author: clicher-dev
  version: 1.0.0
  category: cross-cutting
user-invokable: true
argument-hint: "<version> (例: 0.3.0)"
---

詳細な手順は「INSTRUCTIONS.md」を参照（このスキルのディレクトリ内）。
