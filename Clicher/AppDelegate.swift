import AppKit
import OSLog
import SharedModels
import Utilities
import OverlayUI

/// AppKit 統合用デリゲート
/// グローバルホットキーの登録とキャプチャHUDの管理を担当
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var hudWindow: CaptureHUDWindow?
    private var appState: AppState?
    private var onCapture: ((CaptureMode) -> Void)?

    /// AppState を外部からセット（ClicherApp から呼ばれる）
    func configure(appState: AppState, onCapture: @escaping (CaptureMode) -> Void) {
        self.appState = appState
        self.onCapture = onCapture

        let hud = CaptureHUDWindow(appState: appState)
        hud.onModeSelected = onCapture
        self.hudWindow = hud

        // ⌘⇧A → 即エリアキャプチャ（Lark 風）
        HotkeyManager.shared.onHotkeyPressed = { @MainActor [weak self] in
            self?.onCapture?(.area)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
