import SwiftUI
import Observation

/// アプリ全体の状態管理
@Observable
@MainActor
public final class AppState {
    /// 現在選択されているキャプチャモード
    public var selectedCaptureMode: CaptureMode = .area

    /// キャプチャHUDの表示状態
    public var isHUDVisible = false

    /// 権限ガイドの表示状態
    public var isPermissionGuideVisible = false

    /// Screen Recording 権限の状態
    public var hasScreenRecordingPermission = false

    /// Accessibility 権限の状態
    public var hasAccessibilityPermission = false

    // MARK: - HUD Options

    /// セルフタイマー設定
    public var timerDelay: TimerDelay = .none

    /// クロスヘア表示
    public var showCrosshair = true

    /// ルーペ表示
    public var showMagnifier = true

    public init() {}
}
