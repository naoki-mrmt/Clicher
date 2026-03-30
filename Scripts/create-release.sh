#!/bin/bash
set -euo pipefail

# GitHub Release 作成 + DMG アップロードスクリプト
# 使い方: ./Scripts/create-release.sh <version>
# 例: ./Scripts/create-release.sh 1.0.0

VERSION="${1:?バージョンを指定してください (例: 1.0.0)}"
DMG_PATH="build/Clicher-${VERSION}.dmg"

echo "=== Clicher v${VERSION} リリース ==="

# DMG 確認
if [ ! -f "${DMG_PATH}" ]; then
    echo "❌ ${DMG_PATH} が見つかりません"
    echo "先に ./Scripts/build-release.sh を実行してください"
    exit 1
fi

# タグ作成
echo "🏷️  タグ v${VERSION} を作成..."
git tag -a "v${VERSION}" -m "v${VERSION}"
git push origin "v${VERSION}"

# GitHub Release 作成 + DMG アップロード
echo "📦 GitHub Release を作成中..."
gh release create "v${VERSION}" \
    "${DMG_PATH}" \
    --title "Clicher v${VERSION}" \
    --generate-notes

RELEASE_URL=$(gh release view "v${VERSION}" --json url -q .url)
echo ""
echo "✅ リリース完了!"
echo "URL: ${RELEASE_URL}"
echo ""
echo "次のステップ:"
echo "  1. Homebrew tap を更新: ./Scripts/setup-homebrew-tap.sh ${DMG_PATH}"
echo "  2. Sparkle appcast を更新: ./Scripts/generate-appcast.sh"
