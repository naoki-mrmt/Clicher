#!/bin/bash
set -euo pipefail

# Clicher リリースビルド + 署名 + Notarization + DMG 作成
# 使い方: ./Scripts/build-release.sh <version> [--skip-notarize]
#
# 必要な環境変数（Notarization 時）:
#   APPLE_ID, TEAM_ID, APP_PASSWORD

VERSION="${1:?バージョンを指定してください (例: 0.0.4)}"
SKIP_NOTARIZE=false
if [[ "${2:-}" == "--skip-notarize" ]]; then
    SKIP_NOTARIZE=true
fi

APP_NAME="Clicher"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Developer ID Application: Naoki Muramoto (JFWN5K94GG)}"

echo "=== ${APP_NAME} v${VERSION} Release Build ==="

# 1. クリーン
rm -rf "${BUILD_DIR}"

# 2. アーカイブ（署名付き）
echo "📦 アーカイブ作成中..."
xcodebuild archive \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="${SIGNING_IDENTITY}" \
    DEVELOPMENT_TEAM=JFWN5K94GG \
    ENABLE_APP_SANDBOX=NO \
    ENABLE_HARDENED_RUNTIME=YES \
    | tail -1

# 3. エクスポート
echo "📤 エクスポート中..."
mkdir -p "${EXPORT_DIR}"
cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${APP_PATH}"

# 4. 署名確認
echo "🔐 署名確認..."
codesign -dvv "${APP_PATH}" 2>&1 | grep "Authority"

# 5. DMG 作成
echo "💿 DMG 作成中..."
hdiutil create \
    -volname "${APP_NAME}" \
    -srcfolder "${EXPORT_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

# 6. Notarization
if [ "${SKIP_NOTARIZE}" = false ]; then
    APPLE_ID="${APPLE_ID:-nitro.poodle@icloud.com}"
    TEAM_ID="${TEAM_ID:-JFWN5K94GG}"

    if [ -z "${APP_PASSWORD:-}" ]; then
        echo "⚠️  APP_PASSWORD が未設定です。Notarization をスキップします"
        echo "  export APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    else
        echo "🔏 Notarization 送信中..."
        xcrun notarytool submit "${DMG_PATH}" \
            --apple-id "${APPLE_ID}" \
            --team-id "${TEAM_ID}" \
            --password "${APP_PASSWORD}" \
            --wait

        echo "📎 Stapling..."
        xcrun stapler staple "${DMG_PATH}"
        echo "✅ Notarization 完了"
    fi
fi

# 7. SHA-256 計算
SHA256=$(shasum -a 256 "${DMG_PATH}" | awk '{print $1}')

# 8. サマリー
echo ""
echo "=== リリースサマリー ==="
echo "バージョン: ${VERSION}"
echo "DMG: ${DMG_PATH}"
ls -lh "${DMG_PATH}"
echo "SHA-256: ${SHA256}"
echo ""
echo "次のステップ:"
echo "  git tag -a v${VERSION} -m 'v${VERSION}' && git push origin v${VERSION}"
echo "  gh release create v${VERSION} ${DMG_PATH} --title '${APP_NAME} v${VERSION}' --generate-notes"
echo "  # Homebrew tap 更新: SHA-256 = ${SHA256}"
