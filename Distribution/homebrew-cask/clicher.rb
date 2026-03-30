# Homebrew Cask テンプレート
# 実際の配布時に URL と sha256 を更新する
cask "clicher" do
  version "1.0.0"
  sha256 "PLACEHOLDER_SHA256"

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
