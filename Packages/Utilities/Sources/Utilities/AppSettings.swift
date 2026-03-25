import AppKit
import Observation
import OSLog
import SharedModels

/// アプリ設定の永続化
/// UserDefaults を使用してユーザー設定を保存・読み込み
@Observable
@MainActor
public final class AppSettings {
    // MARK: - Save Settings

    /// デフォルトの保存先ディレクトリ
    public var saveDirectory: URL {
        didSet { save("saveDirectory", url: saveDirectory) }
    }

    /// ファイル命名パターン
    public var fileNamePattern: FileNamePattern {
        didSet { save("fileNamePattern", value: fileNamePattern.rawValue) }
    }

    /// 画像フォーマット
    public var imageFormat: ImageFormat {
        didSet { save("imageFormat", value: imageFormat.rawValue) }
    }

    // MARK: - Capture Settings

    /// Retina 解像度でキャプチャするか
    public var captureRetina: Bool {
        didSet { save("captureRetina", value: captureRetina) }
    }

    // MARK: - Overlay Settings

    /// Quick Access Overlay の表示位置
    public var overlayPosition: OverlayPosition {
        didSet { save("overlayPosition", value: overlayPosition.rawValue) }
    }

    /// Quick Access Overlay の自動クローズ秒数（0 = 自動クローズなし）
    public var overlayAutoCloseSeconds: Int {
        didSet { save("overlayAutoCloseSeconds", value: overlayAutoCloseSeconds) }
    }

    // MARK: - Launch Settings

    /// ログイン時に起動するか
    public var launchAtLogin: Bool {
        didSet { save("launchAtLogin", value: launchAtLogin) }
    }

    // MARK: - Init

    public init() {
        let defaults = UserDefaults.standard

        // 保存先
        if let path = defaults.string(forKey: "saveDirectory"),
           let url = URL(string: path) {
            self.saveDirectory = url
        } else {
            self.saveDirectory = FileManager.default.urls(
                for: .desktopDirectory, in: .userDomainMask
            ).first ?? FileManager.default.temporaryDirectory
        }

        // ファイル名パターン
        self.fileNamePattern = FileNamePattern(
            rawValue: defaults.string(forKey: "fileNamePattern") ?? ""
        ) ?? .dateTime

        // 画像フォーマット
        self.imageFormat = ImageFormat(
            rawValue: defaults.string(forKey: "imageFormat") ?? ""
        ) ?? .png

        // Retina
        self.captureRetina = defaults.object(forKey: "captureRetina") as? Bool ?? true

        // Overlay
        self.overlayPosition = OverlayPosition(
            rawValue: defaults.string(forKey: "overlayPosition") ?? ""
        ) ?? .bottomRight
        self.overlayAutoCloseSeconds = defaults.object(forKey: "overlayAutoCloseSeconds") as? Int ?? 5

        // Launch
        self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    }

    // MARK: - Persistence Helpers

    private func save(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
    }

    private func save(_ key: String, url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: key)
    }
}
