import AppKit
import OSLog

/// AppKit 統合用デリゲート
/// グローバルホットキーの登録とキャプチャHUDの管理を担当
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var hudWindow: CaptureHUDWindow?
    private var appState: AppState?

    /// AppState を外部からセット（ClicherApp から呼ばれる）
    func configure(appState: AppState, onCapture: @escaping (CaptureMode) -> Void) {
        self.appState = appState

        let hud = CaptureHUDWindow(appState: appState)
        hud.onModeSelected = onCapture
        self.hudWindow = hud

        // ⌘⇧A ホットキーのコールバック設定
        HotkeyManager.shared.onHotkeyPressed = { @MainActor [weak hud] in
            hud?.toggle()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
