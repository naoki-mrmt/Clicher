#!/bin/bash
set -euo pipefail

# Sparkle appcast.xml 生成スクリプト
# Sparkle の generate_appcast ツールを使用
# 使い方: ./Scripts/generate-appcast.sh <releases-dir>

RELEASES_DIR="${1:-.}"
APPCAST_PATH="appcast.xml"

echo "=== Appcast 生成 ==="

# Sparkle の generate_appcast が利用可能かチェック
if command -v generate_appcast &> /dev/null; then
    generate_appcast "${RELEASES_DIR}"
    echo "✅ appcast.xml 生成完了"
else
    echo "⚠️  generate_appcast が見つかりません"
    echo "Sparkle をインストールしてください:"
    echo "  brew install sparkle"
    echo ""
    echo "または手動で appcast.xml を作成してください"

    # テンプレート出力
    cat > "${APPCAST_PATH}" << 'APPCAST'
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Clicher Updates</title>
    <link>https://example.com/appcast.xml</link>
    <description>Clicher macOS app updates</description>
    <language>ja</language>
    <item>
      <title>Version 1.0.0</title>
      <sparkle:version>1</sparkle:version>
      <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
      <pubDate><!-- DATE --></pubDate>
      <enclosure
        url="https://example.com/releases/Clicher-1.0.0.dmg"
        sparkle:edSignature="<!-- ED25519 SIGNATURE -->"
        length="<!-- FILE SIZE -->"
        type="application/octet-stream"
      />
    </item>
  </channel>
</rss>
APPCAST
    echo "📝 テンプレート appcast.xml を出力しました"
fi
