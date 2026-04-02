import Foundation

/// 多言語対応の文字列カタログ
/// 日本語 (デフォルト) + 英語
public enum L10n {
    private static var isEnglish: Bool {
        Locale.current.language.languageCode?.identifier == "en"
    }

    private static func localized(ja: String, en: String) -> String {
        isEnglish ? en : ja
    }

    // MARK: - Common

    public static var save: String { localized(ja: "保存", en: "Save") }
    public static var copy: String { localized(ja: "コピー", en: "Copy") }
    public static var edit: String { localized(ja: "編集", en: "Edit") }
    public static var delete: String { localized(ja: "削除", en: "Delete") }
    public static var cancel: String { localized(ja: "キャンセル", en: "Cancel") }
    public static var done: String { localized(ja: "完了", en: "Done") }
    public static var ok: String { localized(ja: "OK", en: "OK") }
    public static var error: String { localized(ja: "エラー", en: "Error") }
    public static var settings: String { localized(ja: "設定...", en: "Settings...") }
    public static var quit: String { localized(ja: "終了", en: "Quit") }

    // MARK: - Capture

    public static var capture: String { localized(ja: "キャプチャ", en: "Capture") }
    public static var screenshot: String { localized(ja: "スクリーンショット", en: "Screenshot") }
    public static var scrollCapture: String { localized(ja: "スクロールキャプチャ", en: "Scroll Capture") }
    public static var screenRecording: String { localized(ja: "画面収録", en: "Screen Recording") }
    public static var recognizeText: String { localized(ja: "テキストを認識", en: "Recognize Text") }

    // MARK: - Quick Access

    public static var pin: String { localized(ja: "ピン留め", en: "Pin") }
    public static var clickToPreview: String { localized(ja: "クリックでプレビュー拡大", en: "Click to preview") }
    public static var recognizedText: String { localized(ja: "認識テキスト", en: "Recognized Text") }

    // MARK: - Toast

    public static var copied: String { localized(ja: "コピーしました", en: "Copied") }
    public static func saved(_ filename: String) -> String {
        localized(ja: "保存しました: \(filename)", en: "Saved: \(filename)")
    }
    public static var saveFailed: String { localized(ja: "画像の保存に失敗しました", en: "Failed to save image") }

    // MARK: - Permissions

    public static var permissionsRequired: String {
        localized(ja: "Clicher を使うには権限が必要です", en: "Clicher requires permissions")
    }
    public static var permissionsDescription: String {
        localized(
            ja: "スクリーンショットとグローバルホットキーを使用するために、以下の権限を許可してください。",
            en: "Please grant the following permissions for screenshots and global hotkeys."
        )
    }
    public static var screenRecordingDesc: String {
        localized(ja: "画面の内容をキャプチャするために必要です", en: "Required to capture screen content")
    }
    public static var accessibilityDesc: String {
        localized(ja: "グローバルホットキー (⌘⇧A) の動作に必要です", en: "Required for global hotkey (⌘⇧A)")
    }
    public static var granted: String { localized(ja: "許可済み", en: "Granted") }
    public static var grant: String { localized(ja: "許可", en: "Grant") }
    public static var letsBegin: String { localized(ja: "始める", en: "Let's Begin") }
    public static var setUpLater: String { localized(ja: "あとで設定する", en: "Set Up Later") }
    public static var openSystemSettings: String { localized(ja: "システム設定を開く", en: "Open System Settings") }

    // MARK: - Settings

    public static var general: String { localized(ja: "一般", en: "General") }
    public static var captureSettings: String { localized(ja: "キャプチャ", en: "Capture") }
    public static var brand: String { localized(ja: "ブランド", en: "Brand") }
    public static var permissions: String { localized(ja: "権限", en: "Permissions") }
    public static var saveDirectory: String { localized(ja: "保存先", en: "Save Location") }
    public static var change: String { localized(ja: "変更...", en: "Change...") }
    public static var fileName: String { localized(ja: "ファイル名", en: "File Name") }
    public static var imageFormat: String { localized(ja: "画像形式", en: "Image Format") }
    public static var launchAtLogin: String { localized(ja: "ログイン時に起動", en: "Launch at Login") }
    public static var retinaCapture: String { localized(ja: "Retina 解像度でキャプチャ (2x)", en: "Capture at Retina resolution (2x)") }
    public static var overlayPosition: String { localized(ja: "表示位置", en: "Position") }
    public static func autoCloseSeconds(_ n: Int) -> String {
        localized(ja: "自動クローズ: \(n)秒", en: "Auto-close: \(n)s")
    }
    public static var autoCloseDisabled: String {
        localized(ja: "自動クローズは無効です", en: "Auto-close is disabled")
    }

    // MARK: - History

    public static var captureHistory: String { localized(ja: "キャプチャ履歴", en: "Capture History") }
    public static var selectHistory: String { localized(ja: "履歴を選択", en: "Select a capture") }
    public static func itemCount(_ n: Int) -> String {
        localized(ja: "\(n) 件", en: "\(n) items")
    }
    public static var clearAll: String { localized(ja: "全削除", en: "Clear All") }
    public static var showInFinder: String { localized(ja: "Finder で表示", en: "Show in Finder") }
    public static var mode: String { localized(ja: "モード", en: "Mode") }
    public static var size: String { localized(ja: "サイズ", en: "Size") }
    public static var dateTime: String { localized(ja: "日時", en: "Date") }
    public static var file: String { localized(ja: "ファイル", en: "File") }
    public static var preview: String { localized(ja: "プレビュー", en: "Preview") }

    // MARK: - About

    public static var about: String { localized(ja: "Clicher について", en: "About Clicher") }

    // MARK: - Brand Presets

    public static var brandPresets: String { localized(ja: "ブランドプリセット", en: "Brand Presets") }
    public static var brandDescription: String {
        localized(
            ja: "キャプチャにブランドカラー・ロゴを自動適用。チームで .clipreset ファイルを共有できます。",
            en: "Auto-apply brand colors and logos to captures. Share .clipreset files with your team."
        )
    }
    public static var selectOrAddPreset: String {
        localized(ja: "プリセットを選択または追加", en: "Select or add a preset")
    }
    public static var addPresetHint: String {
        localized(
            ja: "左下の + ボタンで新規作成\nまたは .clipreset ファイルをインポート",
            en: "Click + to create new\nor import a .clipreset file"
        )
    }
    public static var recording: String { localized(ja: "録画中", en: "Recording") }

    // MARK: - Inline Annotate

    public static var annotateCancel: String { localized(ja: "キャンセル", en: "Cancel") }
    public static var annotateDone: String { localized(ja: "クリップボードにコピー", en: "Copy to Clipboard") }
    public static var annotateSave: String { localized(ja: "保存", en: "Save") }

    // MARK: - Scroll Capture

    public static func frameCount(_ n: Int) -> String {
        localized(ja: "\(n) フレーム", en: "\(n) frames")
    }
    public static var captureFrame: String { localized(ja: "キャプチャ", en: "Capture") }

    // MARK: - Floating Screenshot

    public static var clickThrough: String { localized(ja: "クリックスルー", en: "Click Through") }
    public static var opacity: String { localized(ja: "不透明度", en: "Opacity") }

    // MARK: - Window Capture

    public static var removeShadow: String { localized(ja: "影を除去", en: "Remove Shadow") }
}
