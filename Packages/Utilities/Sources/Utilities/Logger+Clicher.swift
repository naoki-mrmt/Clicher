import OSLog

extension Logger {
    /// バンドルIDをサブシステムとして使用
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.naoki-mrmt.Clicher"

    /// アプリ全般のログ
    public static let app = Logger(subsystem: subsystem, category: "app")

    /// ホットキー関連のログ
    public static let hotkey = Logger(subsystem: subsystem, category: "hotkey")

    /// 権限関連のログ
    public static let permission = Logger(subsystem: subsystem, category: "permission")

    /// キャプチャ関連のログ
    public static let capture = Logger(subsystem: subsystem, category: "capture")

    /// ログイン項目関連のログ
    public static let loginItem = Logger(subsystem: subsystem, category: "loginItem")
}
