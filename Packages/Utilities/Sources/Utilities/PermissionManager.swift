import ScreenCaptureKit
import AppKit
import OSLog
import Observation

/// Screen Recording / Accessibility 権限の管理
@Observable
@MainActor
public final class PermissionManager {
    /// Screen Recording 権限の状態
    public private(set) var hasScreenRecordingPermission = false

    /// Accessibility 権限の状態
    public private(set) var hasAccessibilityPermission = false

    public init() {}

    /// 全権限を確認
    public func checkAll() {
        checkScreenRecording()
        checkAccessibility()
    }

    // MARK: - Screen Recording

    /// Screen Recording 権限を確認
    public func checkScreenRecording() {
        hasScreenRecordingPermission = CGPreflightScreenCaptureAccess()
    }

    /// Screen Recording 権限をリクエスト
    public func requestScreenRecording() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
            Logger.permission.info("Screen Recording 権限をリクエストしました")
        }
        checkScreenRecording()
    }

    // MARK: - Accessibility

    /// Accessibility 権限を確認
    public func checkAccessibility() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    /// Accessibility 権限をリクエスト（システム設定を開く）
    public func requestAccessibility() {
        // kAXTrustedCheckOptionPrompt は concurrency-unsafe なグローバル変数のため直接参照を避ける
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        Logger.permission.info("Accessibility 権限をリクエストしました")
        // ダイアログ表示後に再チェック
        Task {
            try? await Task.sleep(for: .seconds(1))
            checkAccessibility()
        }
    }

    // MARK: - System Settings

    /// Screen Recording のシステム設定を開く
    public func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else {
            Logger.permission.error("Screen Recording 設定URLの生成に失敗")
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Accessibility のシステム設定を開く
    public func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            Logger.permission.error("Accessibility 設定URLの生成に失敗")
            return
        }
        NSWorkspace.shared.open(url)
    }
}
