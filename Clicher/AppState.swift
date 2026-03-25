import SwiftUI
import Observation

/// アプリ全体の状態管理
@Observable
final class AppState {
    /// 現在選択されているキャプチャモード
    var selectedCaptureMode: CaptureMode = .area

    /// キャプチャHUDの表示状態
    var isHUDVisible = false

    /// 権限ガイドの表示状態
    var isPermissionGuideVisible = false

    /// Screen Recording 権限の状態
    var hasScreenRecordingPermission = false

    /// Accessibility 権限の状態
    var hasAccessibilityPermission = false

    // MARK: - HUD Options

    /// セルフタイマー設定
    var timerDelay: TimerDelay = .none

    /// クロスヘア表示
    var showCrosshair = true

    /// ルーペ表示
    var showMagnifier = true
}

// MARK: - CaptureMode

/// キャプチャモード
enum CaptureMode: Int, CaseIterable, Identifiable, Sendable {
    case area = 1
    case window = 2
    case fullscreen = 3
    case scroll = 4
    case ocr = 5
    case recording = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .area: "エリア"
        case .window: "ウィンドウ"
        case .fullscreen: "フルスクリーン"
        case .scroll: "スクロール"
        case .ocr: "OCR"
        case .recording: "録画"
        }
    }

    var systemImage: String {
        switch self {
        case .area: "rectangle.dashed"
        case .window: "macwindow"
        case .fullscreen: "desktopcomputer"
        case .scroll: "scroll"
        case .ocr: "doc.text.viewfinder"
        case .recording: "record.circle"
        }
    }

    var shortcutKey: String {
        "\(rawValue)"
    }

    /// Phase 1 で利用可能なモード
    var isAvailable: Bool {
        switch self {
        case .area, .window, .fullscreen: true
        case .scroll, .ocr, .recording: false
        }
    }

    /// Phase 1 で利用可能なモードのみ
    static var availableModes: [CaptureMode] {
        allCases.filter(\.isAvailable)
    }
}

// MARK: - TimerDelay

/// セルフタイマー設定
enum TimerDelay: Int, CaseIterable, Identifiable, Sendable {
    case none = 0
    case threeSeconds = 3
    case fiveSeconds = 5
    case tenSeconds = 10

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .none: "なし"
        case .threeSeconds: "3秒"
        case .fiveSeconds: "5秒"
        case .tenSeconds: "10秒"
        }
    }
}
