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
        case .area: L10n.modeArea
        case .window: L10n.modeWindow
        case .fullscreen: L10n.modeFullscreen
        case .scroll: L10n.modeScroll
        case .ocr: L10n.modeOCR
        case .recording: L10n.modeRecording
        }
    }

    public var systemImage: String {
        switch self {
        case .area: "rectangle.dashed"
        case .window: "macwindow"
        case .fullscreen: "desktopcomputer"
        case .scroll: "rectangle.arrowtriangle.2.outward"
        case .ocr: "doc.text.viewfinder"
        case .recording: "record.circle"
        }
    }

    public var shortcutKey: String {
        "\(rawValue)"
    }
}
