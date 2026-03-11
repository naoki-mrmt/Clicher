import Foundation

/// スクリーンキャプチャのモード
enum CaptureMode: String, CaseIterable, Identifiable, Sendable {
    case area
    case window
    case fullscreen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .area: "Capture Area"
        case .window: "Capture Window"
        case .fullscreen: "Capture Fullscreen"
        }
    }

    var shortcutSymbol: String {
        switch self {
        case .area: "rectangle.dashed"
        case .window: "macwindow"
        case .fullscreen: "rectangle.inset.filled"
        }
    }
}
