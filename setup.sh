#!/bin/bash
# Clicher CC セットアップスクリプト
#
# 前提: Xcode で macOS App プロジェクトを先に作成済み
#
# 使い方:
#   1. Xcode → File → New → Project → macOS → App
#      - Product Name: Clicher
#      - Interface: SwiftUI
#      - Language: Swift
#      - 保存先: 任意のディレクトリ
#   2. このzipをプロジェクトルートに展開
#   3. chmod +x setup.sh && ./setup.sh

set -euo pipefail

APP_NAME="Clicher"

# ─────────────────────────────────────────────
# 検証
# ─────────────────────────────────────────────
if [ ! -d "${APP_NAME}.xcodeproj" ] && [ ! -f "Package.swift" ]; then
  echo "❌ エラー: ${APP_NAME}.xcodeproj が見つかりません"
  echo ""
  echo "先に Xcode でプロジェクトを作成してください:"
  echo "  1. Xcode → File → New → Project"
  echo "  2. macOS → App"
  echo "  3. Product Name: ${APP_NAME}"
  echo "  4. Interface: SwiftUI / Language: Swift"
  echo "  5. このディレクトリに保存"
  echo ""
  echo "作成後にもう一度 ./setup.sh を実行してください"
  exit 1
fi

echo "🚀 ${APP_NAME} CC環境をセットアップします..."

# ─────────────────────────────────────────────
# Git 初期化（未初期化の場合）
# ─────────────────────────────────────────────
if [ ! -d .git ]; then
  git init
  echo "✅ Git initialized"
fi

# ─────────────────────────────────────────────
# CC設定の確認
# ─────────────────────────────────────────────
echo "📁 CC設定ファイルを確認..."

# CLAUDE.md
if [ -f CLAUDE.md ]; then
  echo "  ✅ CLAUDE.md"
else
  echo "  ❌ CLAUDE.md が見つかりません（zip展開を確認してください）"
fi

# AGENTS.md
if [ -f AGENTS.md ]; then
  echo "  ✅ AGENTS.md"
else
  echo "  ❌ AGENTS.md が見つかりません"
fi

# .claude/settings.json
if [ -f .claude/settings.json ]; then
  echo "  ✅ .claude/settings.json"
else
  echo "  ❌ .claude/settings.json が見つかりません"
fi

# ─────────────────────────────────────────────
# スキルの確認
# ─────────────────────────────────────────────
echo "📦 CCスキルを確認..."

for skill in swiftui-pro swiftui-expert swift-concurrency-pro swift-testing-pro swiftdata-pro clicher-dev; do
  if [ -f ".claude/skills/${skill}/SKILL.md" ]; then
    echo "  ✅ ${skill}"
  else
    echo "  ❌ ${skill} が見つかりません"
  fi
done

# ─────────────────────────────────────────────
# .gitignore のマージ
# ─────────────────────────────────────────────
if [ -f .gitignore ]; then
  # Xcodeが作った.gitignoreに追記
  if ! grep -q "\.claude/settings\.local\.json" .gitignore 2>/dev/null; then
    cat >> .gitignore << 'GITIGNORE'

# Claude Code
.claude/settings.local.json
GITIGNORE
    echo "✅ .gitignore に CC用エントリを追記"
  fi
fi

# ─────────────────────────────────────────────
# コミット
# ─────────────────────────────────────────────
git add -A
git commit -m "chore: add CC rules, skills, and implementation plan

- CLAUDE.md: project rules and architecture
- AGENTS.md: Paul Hudson Swift/SwiftUI guidelines
- .claude/skills/swiftui-pro: Paul Hudson SwiftUI Pro skill
- .claude/skills/swiftui-expert: AvdLee SwiftUI Expert skill (macOS refs)
- .claude/skills/swift-concurrency-pro: Paul Hudson Swift Concurrency Pro
- .claude/skills/swift-testing-pro: Paul Hudson Swift Testing Pro
- .claude/skills/swiftdata-pro: Paul Hudson SwiftData Pro
- .claude/skills/clicher-dev: project-specific patterns
- IMPLEMENTATION_PLAN.md: 4-phase development plan" || true

echo ""
echo "============================================"
echo "  🎉 ${APP_NAME} CC環境セットアップ完了!"
echo "============================================"
echo ""
echo "次のステップ — CC を起動して最初の指示を出す:"
echo ""
echo '  claude'
echo ""
echo '  → 「IMPLEMENTATION_PLAN.md を読んで Phase 1 の'
echo '     1.2 メニューバーアプリ基盤 から実装を開始して。'
echo '     既存の Xcode プロジェクト構造を活かして。」'
echo ""
echo "配置されたファイル:"
echo "  CLAUDE.md              → CC が自動で読むルール"
echo "  AGENTS.md              → Swift/SwiftUI コーディングガイド"
echo "  IMPLEMENTATION_PLAN.md → 全Phase実装計画"
echo "  .claude/settings.json  → CC権限設定"
echo "  .claude/skills/"
echo "    ├── swiftui-pro/            → Paul Hudson SwiftUI Pro"
echo "    ├── swiftui-expert/         → AvdLee SwiftUI Expert (macOS特化)"
echo "    ├── swift-concurrency-pro/  → Paul Hudson Swift Concurrency"
echo "    ├── swift-testing-pro/      → Paul Hudson Swift Testing"
echo "    ├── swiftdata-pro/          → Paul Hudson SwiftData"
echo "    └── clicher-dev/            → ScreenCaptureKit/Annotate パターン"
echo ""
