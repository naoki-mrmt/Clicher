/// キャプチャモード
public enum CaptureMode: Int, CaseIterable, Identifiable, Sendable {
    case area = 1
    case window = 2
    case fullscreen = 3
    case scroll = 4
    case ocr = 5
    case recording = 6

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .area: "エリア"
        case .window: "ウィンドウ"
        case .fullscreen: "フルスクリーン"
        case .scroll: "スクロール"
        case .ocr: "OCR"
        case .recording: "録画"
        }
    }

    public var systemImage: String {
        switch self {
        case .area: "rectangle.dashed"
        case .window: "macwindow"
        case .fullscreen: "desktopcomputer"
        case .scroll: "scroll"
        case .ocr: "doc.text.viewfinder"
        case .recording: "record.circle"
        }
    }

    public var shortcutKey: String {
        "\(rawValue)"
    }

    /// Phase 1 で利用可能なモード
    public var isAvailable: Bool {
        switch self {
        case .area, .window, .fullscreen, .ocr: true
        case .scroll, .recording: false
        }
    }

    /// Phase 1 で利用可能なモードのみ
    public static var availableModes: [CaptureMode] {
        allCases.filter(\.isAvailable)
    }
}
