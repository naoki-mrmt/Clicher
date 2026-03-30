#!/bin/bash
set -euo pipefail

# Homebrew tap リポジトリのセットアップスクリプト
# 使い方: ./Scripts/setup-homebrew-tap.sh
#
# 前提: gh CLI でログイン済み、DMG がビルド済み
#
# このスクリプトは以下を行う:
# 1. homebrew-clicher リポジトリを作成（なければ）
# 2. Cask ファイルを生成
# 3. リポジトリにプッシュ

GITHUB_USER="naoki-mrmt"
TAP_REPO="homebrew-clicher"
CASK_NAME="clicher"
DMG_PATH="${1:-build/Clicher-*.dmg}"

echo "=== Homebrew Tap セットアップ ==="

# DMG を探す
DMG_FILE=$(ls -1 ${DMG_PATH} 2>/dev/null | head -1)
if [ -z "${DMG_FILE:-}" ]; then
    echo "❌ DMG ファイルが見つかりません: ${DMG_PATH}"
    echo "先に ./Scripts/build-release.sh を実行してください"
    exit 1
fi

# バージョンを取得
VERSION=$(echo "${DMG_FILE}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "1.0.0")
SHA256=$(shasum -a 256 "${DMG_FILE}" | awk '{print $1}')

echo "DMG: ${DMG_FILE}"
echo "Version: ${VERSION}"
echo "SHA-256: ${SHA256}"

# 1. リポジトリ作成（なければ）
if ! gh repo view "${GITHUB_USER}/${TAP_REPO}" &>/dev/null; then
    echo "📦 ${TAP_REPO} リポジトリを作成中..."
    gh repo create "${GITHUB_USER}/${TAP_REPO}" --public \
        --description "Homebrew tap for Clicher - macOS screenshot & annotation tool"
fi

# 2. クローン
TEMP_DIR=$(mktemp -d)
gh repo clone "${GITHUB_USER}/${TAP_REPO}" "${TEMP_DIR}" 2>/dev/null || {
    cd "${TEMP_DIR}"
    git init
    git remote add origin "https://github.com/${GITHUB_USER}/${TAP_REPO}.git"
}

# 3. Cask ファイル生成
mkdir -p "${TEMP_DIR}/Casks"
cat > "${TEMP_DIR}/Casks/${CASK_NAME}.rb" << CASKEOF
cask "${CASK_NAME}" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${GITHUB_USER}/Clicher/releases/download/v#{version}/Clicher-#{version}.dmg"
  name "Clicher"
  desc "Screenshot and annotation tool for macOS"
  homepage "https://github.com/${GITHUB_USER}/Clicher"

  depends_on macos: ">= :sonoma"

  app "Clicher.app"

  zap trash: [
    "~/Library/Application Support/Clicher",
    "~/Library/Preferences/com.naoki-mrmt.Clicher.plist",
    "~/Library/Caches/com.naoki-mrmt.Clicher",
  ]
end
CASKEOF

# README
cat > "${TEMP_DIR}/README.md" << READMEEOF
# homebrew-clicher

Homebrew tap for [Clicher](https://github.com/${GITHUB_USER}/Clicher) - macOS screenshot & annotation tool.

## Install

\`\`\`bash
brew tap ${GITHUB_USER}/clicher
brew install --cask clicher
\`\`\`

## Update

\`\`\`bash
brew upgrade --cask clicher
\`\`\`

## Uninstall

\`\`\`bash
brew uninstall --cask clicher
\`\`\`
READMEEOF

# 4. コミット & プッシュ
cd "${TEMP_DIR}"
git add -A
git commit -m "feat: add clicher cask v${VERSION}" 2>/dev/null || echo "変更なし"
git branch -M main
git push -u origin main 2>/dev/null || git push origin main

echo ""
echo "✅ Homebrew tap セットアップ完了!"
echo ""
echo "インストール方法:"
echo "  brew tap ${GITHUB_USER}/clicher"
echo "  brew install --cask clicher"
echo ""
echo "⚠️  注意: GitHub Releases に Clicher-${VERSION}.dmg をアップロードしてください"

# クリーンアップ
rm -rf "${TEMP_DIR}"
