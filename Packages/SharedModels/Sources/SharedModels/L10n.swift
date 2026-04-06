import Foundation

/// 多言語対応の文字列カタログ
/// 日本語 (デフォルト) + 英語
public enum L10n {
    /// アプリの表示言語（日本語がデフォルト）
    /// ユーザーの優先言語に日本語が含まれない場合のみ英語にフォールバック
    private static var isEnglish: Bool {
        let preferred = Locale.preferredLanguages
        let hasJapanese = preferred.contains { $0.hasPrefix("ja") }
        return !hasJapanese
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

    // MARK: - Capture Mode Labels

    public static var modeArea: String { localized(ja: "エリア", en: "Area") }
    public static var modeWindow: String { localized(ja: "ウィンドウ", en: "Window") }
    public static var modeFullscreen: String { localized(ja: "フルスクリーン", en: "Fullscreen") }
    public static var modeScroll: String { localized(ja: "スクロール", en: "Scroll") }
    public static var modeOCR: String { "OCR" }
    public static var modeRecording: String { localized(ja: "録画", en: "Recording") }
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

    public static var permissionSettings: String { localized(ja: "権限設定", en: "Permission Settings") }
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

    // MARK: - Preview

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

    // MARK: - Permission Labels

    public static var screenRecordingLabel: String { localized(ja: "画面収録", en: "Screen Recording") }
    public static var accessibilityLabel: String { localized(ja: "アクセシビリティ", en: "Accessibility") }

    // MARK: - Settings (additional)

    public static var quickAccessOverlay: String { localized(ja: "Quick Access Overlay", en: "Quick Access Overlay") }

    // MARK: - Brand Presets (detail)

    public static var basicInfo: String { localized(ja: "基本情報", en: "Basic Info") }
    public static var presetName: String { localized(ja: "名前", en: "Name") }
    public static var defaultPreset: String { localized(ja: "デフォルトプリセット", en: "Default Preset") }
    public static var colors: String { localized(ja: "カラー", en: "Colors") }
    public static var primaryColor: String { localized(ja: "プライマリ", en: "Primary") }
    public static var secondaryColor: String { localized(ja: "セカンダリ", en: "Secondary") }
    public static var accentColor: String { localized(ja: "アクセント", en: "Accent") }
    public static var logo: String { localized(ja: "ロゴ", en: "Logo") }
    public static var position: String { localized(ja: "位置", en: "Position") }
    public static var exportAction: String { localized(ja: "エクスポート", en: "Export") }
    public static var importAction: String { localized(ja: "インポート", en: "Import") }
    public static func newPresetName(_ n: Int) -> String {
        localized(ja: "新規プリセット \(n)", en: "New Preset \(n)")
    }
    public static func presetCreateFailed(_ detail: String) -> String {
        localized(ja: "プリセットの作成に失敗しました: \(detail)", en: "Failed to create preset: \(detail)")
    }
    public static func presetDeleteFailed(_ detail: String) -> String {
        localized(ja: "プリセットの削除に失敗しました: \(detail)", en: "Failed to delete preset: \(detail)")
    }
    public static func presetSaveFailed(_ detail: String) -> String {
        localized(ja: "プリセットの保存に失敗しました: \(detail)", en: "Failed to save preset: \(detail)")
    }
    public static func importFailed(_ detail: String) -> String {
        localized(ja: "インポートに失敗しました: \(detail)", en: "Import failed: \(detail)")
    }
    public static func exportFailed(_ detail: String) -> String {
        localized(ja: "エクスポートに失敗しました: \(detail)", en: "Export failed: \(detail)")
    }

    // MARK: - Video Editor

    public static var videoEditor: String { localized(ja: "動画エディタ", en: "Video Editor") }
    public static var trim: String { localized(ja: "トリム", en: "Trim") }
    public static var trimStart: String { localized(ja: "開始", en: "Start") }
    public static var trimEnd: String { localized(ja: "終了", en: "End") }
    public static func selectedRange(_ time: String) -> String {
        localized(ja: "選択範囲: \(time)", en: "Selection: \(time)")
    }
    public static var quality: String { localized(ja: "品質", en: "Quality") }
    public static var qualityHigh: String { localized(ja: "高画質", en: "High") }
    public static var qualityMedium: String { localized(ja: "標準", en: "Medium") }
    public static var qualityLow: String { localized(ja: "低画質", en: "Low") }
    public static var hasAudio: String { localized(ja: "音声あり", en: "Has Audio") }
    public static var noAudio: String { localized(ja: "音声なし", en: "No Audio") }
    public static var loading: String { localized(ja: "読み込み中...", en: "Loading...") }
    public static var convertToGIF: String { localized(ja: "GIF に変換", en: "Convert to GIF") }

    // MARK: - Annotate Editor

    public static var fill: String { localized(ja: "塗りつぶし", en: "Fill") }
    public static var backgroundSettings: String { localized(ja: "背景設定", en: "Background") }
    public static var textPlaceholder: String { localized(ja: "テキストを入力", en: "Enter text") }

    // MARK: - Background Settings

    public static var addBackground: String { localized(ja: "背景を追加", en: "Add Background") }
    public static var bgTypeSolid: String { localized(ja: "単色", en: "Solid") }
    public static var bgTypeGradient: String { localized(ja: "グラデーション", en: "Gradient") }
    public static var bgType: String { localized(ja: "タイプ", en: "Type") }
    public static var bgColor: String { localized(ja: "背景色", en: "Background Color") }
    public static var gradientStartColor: String { localized(ja: "開始色", en: "Start Color") }
    public static var gradientEndColor: String { localized(ja: "終了色", en: "End Color") }
    public static var angle: String { localized(ja: "角度", en: "Angle") }
    public static var padding: String { localized(ja: "余白", en: "Padding") }
    public static var cornerRadius: String { localized(ja: "角丸", en: "Corner Radius") }
    public static var shadow: String { localized(ja: "影", en: "Shadow") }
    public static var snsPresets: String { localized(ja: "SNS プリセット", en: "SNS Presets") }
    public static var resetSize: String { localized(ja: "サイズリセット", en: "Reset Size") }

    // MARK: - HUD

    public static var crosshair: String { localized(ja: "クロスヘア", en: "Crosshair") }
    public static var loupe: String { localized(ja: "ルーペ", en: "Loupe") }

    // MARK: - Processing

    public static var processingOCR: String { localized(ja: "テキストを認識中...", en: "Recognizing text...") }
    public static var processingStitch: String { localized(ja: "画像を結合中...", en: "Stitching images...") }
    public static var hotkeyRegistrationFailed: String {
        localized(
            ja: "ホットキーの登録に失敗しました。システム設定 → プライバシーとセキュリティ → アクセシビリティ を確認してください。",
            en: "Hotkey registration failed. Please check System Settings → Privacy & Security → Accessibility."
        )
    }
}
