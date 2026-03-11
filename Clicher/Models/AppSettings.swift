import Foundation
import SwiftUI

/// アプリ全体の設定を管理
@Observable
final class AppSettings {
    // MARK: - Hotkey Settings

    var areaCaptureHotkey: KeyCombo = KeyCombo(key: "4", modifiers: [.command, .shift])
    var windowCaptureHotkey: KeyCombo = KeyCombo(key: "5", modifiers: [.command, .shift])
    var fullscreenCaptureHotkey: KeyCombo = KeyCombo(key: "6", modifiers: [.command, .shift])

    // MARK: - Save Settings

    var defaultSaveDirectory: URL = URL.desktopDirectory
    var fileNamePattern: FileNamePattern = .dateTime
    var defaultExportFormat: ExportFormat = .png
    var retinaScale: RetinaScale = .native

    // MARK: - Overlay Settings

    var overlayPosition: OverlayPosition = .bottomRight
    var overlayAutoCloseDelay: TimeInterval = 5.0
    var showOverlayAfterCapture: Bool = true

    // MARK: - General

    var launchAtLogin: Bool = false

    /// 設定をUserDefaultsに保存
    func save() {
        // UserDefaults persistence will be implemented
    }

    /// UserDefaultsから設定を読み込み
    func load() {
        // UserDefaults persistence will be implemented
    }
}

/// キーコンビネーション
struct KeyCombo: Sendable {
    var key: String
    var modifiers: NSEvent.ModifierFlags

    var displayString: String {
        var parts: [String] = []
        if modifiers.contains(.command) { parts.append("⌘") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.control) { parts.append("⌃") }
        parts.append(key.uppercased())
        return parts.joined()
    }
}

/// ファイル命名パターン
enum FileNamePattern: String, CaseIterable, Identifiable, Sendable {
    case dateTime
    case sequential
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dateTime: "Date & Time"
        case .sequential: "Sequential Number"
        case .custom: "Custom Pattern"
        }
    }

    func generateName(index: Int = 0) -> String {
        switch self {
        case .dateTime:
            let now = Date.now
            return "Clicher \(now.formatted(date: .numeric, time: .standard))"
                .replacing("/", with: "-")
                .replacing(":", with: ".")
        case .sequential:
            return "Clicher-\(index, format: .number.precision(.integerLength(4)))"
        case .custom:
            return "Clicher-capture"
        }
    }
}

/// Retina スケール設定
enum RetinaScale: String, CaseIterable, Identifiable, Sendable {
    case native
    case standard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .native: "Native (Retina)"
        case .standard: "Standard (1x)"
        }
    }
}

/// Overlay 表示位置
enum OverlayPosition: String, CaseIterable, Identifiable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .topLeft: "Top Left"
        case .topRight: "Top Right"
        case .bottomLeft: "Bottom Left"
        case .bottomRight: "Bottom Right"
        }
    }
}
