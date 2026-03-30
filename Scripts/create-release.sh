#!/bin/bash
set -euo pipefail

# Clicher フルリリーススクリプト
# ビルド → Notarization → タグ → GitHub Release → Homebrew 更新
#
# 使い方: APP_PASSWORD=xxxx ./Scripts/create-release.sh <version>
# 例: APP_PASSWORD=ahvw-xsom-hcul-jngu ./Scripts/create-release.sh 0.0.5

VERSION="${1:?バージョンを指定してください (例: 0.0.5)}"
DMG_PATH="build/Clicher-${VERSION}.dmg"

echo "=== Clicher v${VERSION} フルリリース ==="

# 1. ビルド + Notarization
./Scripts/build-release.sh "${VERSION}"

# DMG 存在確認
if [ ! -f "${DMG_PATH}" ]; then
    echo "❌ ${DMG_PATH} が見つかりません"
    exit 1
fi

SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

# 2. タグ作成
echo ""
echo "🏷️  タグ v${VERSION} を作成..."
git tag -a "v${VERSION}" -m "v${VERSION}"
git push origin "v${VERSION}"

# 3. GitHub Release 作成（staple 済み DMG をアップロード）
echo "📦 GitHub Release を作成中..."
gh release create "v${VERSION}" \
    "${DMG_PATH}" \
    --title "Clicher v${VERSION}" \
    --generate-notes

# 4. Homebrew tap 更新（ダウンロード後の SHA を使用）
echo "🍺 Homebrew tap を更新中..."
echo "📥 ダウンロード後の SHA-256 を取得..."
sleep 5  # GitHub が CDN に反映するまで待つ
SHA256=$(curl -sL "https://github.com/naoki-mrmt/Clicher/releases/download/v${VERSION}/Clicher-${VERSION}.dmg" | shasum -a 256 | awk '{print $1}')
echo "SHA-256 (download): ${SHA256}"

TEMP_DIR=$(mktemp -d)
git clone git@github.com:naoki-mrmt/homebrew-clicher.git "${TEMP_DIR}" 2>/dev/null
cd "${TEMP_DIR}"
git checkout -b "chore/bump-${VERSION}"

cat > Casks/clicher.rb << CASK
cask "clicher" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/naoki-mrmt/Clicher/releases/download/v#{version}/Clicher-#{version}.dmg"
  name "Clicher"
  desc "Screenshot and annotation tool for macOS"
  homepage "https://github.com/naoki-mrmt/Clicher"

  depends_on macos: ">= :sonoma"

  app "Clicher.app"

  zap trash: [
    "~/Library/Application Support/Clicher",
    "~/Library/Preferences/com.naoki-mrmt.Clicher.plist",
    "~/Library/Caches/com.naoki-mrmt.Clicher",
  ]
end
CASK

git add -A
git commit -m "chore: bump clicher to ${VERSION}"
git push -u origin "chore/bump-${VERSION}"
gh pr create --repo naoki-mrmt/homebrew-clicher \
    --base main \
    --head "chore/bump-${VERSION}" \
    --title "chore: bump to ${VERSION}" \
    --body "SHA-256: ${SHA256}"
gh pr merge --repo naoki-mrmt/homebrew-clicher \
    "chore/bump-${VERSION}" --merge --delete-branch 2>/dev/null || true

cd -
rm -rf "${TEMP_DIR}"

# 5. サマリー
RELEASE_URL=$(gh release view "v${VERSION}" --json url -q .url)
echo ""
echo "=== ✅ リリース完了 ==="
echo "Release: ${RELEASE_URL}"
echo "SHA-256: ${SHA256}"
echo ""
echo "インストール確認:"
echo "  brew untap naoki-mrmt/clicher; brew tap naoki-mrmt/clicher && brew install --cask clicher"
