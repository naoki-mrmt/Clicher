import ScreenCaptureKit
import AppKit

/// Screen Recording / Accessibility 権限の管理
@Observable
final class PermissionManager {
    var hasScreenRecordingPermission = false
    var hasAccessibilityPermission = false

    /// Screen Recording 権限をチェック
    func checkScreenRecordingPermission() async {
        do {
            // SCShareableContent.current を呼ぶことで権限チェックが走る
            _ = try await SCShareableContent.current
            hasScreenRecordingPermission = true
        } catch {
            hasScreenRecordingPermission = false
        }
    }

    /// Accessibility 権限をチェック
    func checkAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    /// Screen Recording 権限の設定画面を開く
    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Accessibility 権限の設定画面を開く
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// 全権限をチェック
    func checkAllPermissions() async {
        await checkScreenRecordingPermission()
        checkAccessibilityPermission()
    }

    /// Accessibility 権限をリクエスト（ダイアログ表示）
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        checkAccessibilityPermission()
    }
}
