import Foundation
import OSLog

/// アプリのバージョン情報
public struct AppVersion: Sendable {
    public let version: String
    public let build: String

    public init() {
        self.version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
        self.build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    }

    public var displayString: String {
        "\(version) (\(build))"
    }
}

/// アップデートチェック管理
/// Sparkle が利用可能な場合は Sparkle を使用し、なければ手動チェックにフォールバック
@MainActor
public final class UpdateManager {
    /// appcast.xml の URL
    public let feedURL: URL?

    /// 最終チェック日時
    public private(set) var lastCheckDate: Date?

    /// アップデートが利用可能か
    public private(set) var updateAvailable = false

    public init(feedURL: URL? = nil) {
        self.feedURL = feedURL
    }

    /// アップデートを確認
    public func checkForUpdates() {
        lastCheckDate = Date()
        Logger.app.info("アップデート確認: \(AppVersion().displayString)")
        // Sparkle が統合されている場合は SUUpdater.shared.checkForUpdates() を呼ぶ
        // 現時点ではプレースホルダー
    }

    /// 自動アップデートチェックの設定
    public func setAutomaticChecks(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "automaticUpdateChecks")
        Logger.app.info("自動アップデートチェック: \(enabled ? "有効" : "無効")")
    }

    public var automaticChecksEnabled: Bool {
        UserDefaults.standard.object(forKey: "automaticUpdateChecks") as? Bool ?? true
    }
}
