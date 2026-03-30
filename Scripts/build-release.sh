#!/bin/bash
set -euo pipefail

# Clicher リリースビルド + DMG 作成 + Notarization スクリプト
# 使い方: ./Scripts/build-release.sh [--skip-notarize]

APP_NAME="Clicher"
SCHEME="Clicher"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
VOLUME_NAME="${APP_NAME}"

SKIP_NOTARIZE=false
if [[ "${1:-}" == "--skip-notarize" ]]; then
    SKIP_NOTARIZE=true
fi

echo "=== ${APP_NAME} Release Build ==="

# 1. クリーンビルド
echo "📦 アーカイブ作成中..."
xcodebuild archive \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    -destination "generic/platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    ENABLE_APP_SANDBOX=NO

# 2. エクスポート
echo "📤 エクスポート中..."
xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist Scripts/ExportOptions.plist \
    2>/dev/null || {
        # ExportOptions.plist がなければ直接 .app を取り出す
        echo "ExportOptions.plist がないため、直接コピーします"
        mkdir -p "${EXPORT_PATH}"
        cp -R "${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app" "${EXPORT_PATH}/"
    }

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ ${APP_PATH} が見つかりません"
    exit 1
fi

# 3. バージョン取得
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "${APP_PATH}/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${APP_PATH}/Contents/Info.plist")
echo "📋 バージョン: ${VERSION} (${BUILD})"

DMG_PATH="${BUILD_DIR}/${APP_NAME}-${VERSION}.dmg"

# 4. DMG 作成
echo "💿 DMG 作成中..."
rm -f "${DMG_PATH}"

hdiutil create \
    -volname "${VOLUME_NAME}" \
    -srcfolder "${EXPORT_PATH}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"

echo "✅ DMG 作成完了: ${DMG_PATH}"

# 5. Notarization（オプション）
if [ "${SKIP_NOTARIZE}" = false ]; then
    echo "🔏 Notarization 送信中..."
    echo "注意: APPLE_ID, TEAM_ID, APP_PASSWORD 環境変数が必要です"

    if [ -z "${APPLE_ID:-}" ] || [ -z "${TEAM_ID:-}" ] || [ -z "${APP_PASSWORD:-}" ]; then
        echo "⚠️  Notarization をスキップ（環境変数未設定）"
        echo "  export APPLE_ID=your@apple.id"
        echo "  export TEAM_ID=XXXXXXXXXX"
        echo "  export APP_PASSWORD=xxxx-xxxx-xxxx-xxxx"
    else
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

# 6. サマリー
echo ""
echo "=== リリースサマリー ==="
echo "バージョン: ${VERSION} (${BUILD})"
echo "DMG: ${DMG_PATH}"
ls -lh "${DMG_PATH}"
echo ""
echo "SHA-256:"
shasum -a 256 "${DMG_PATH}"
