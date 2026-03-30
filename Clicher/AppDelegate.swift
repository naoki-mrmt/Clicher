import AppKit
import OSLog
import SharedModels
import Utilities
import CaptureEngine
import OverlayUI

/// AppKit 統合用デリゲート
/// グローバルホットキーの登録とキャプチャの管理を担当
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var hudWindow: CaptureHUDWindow?
    private var appState: AppState?
    private var captureCoordinator: CaptureCoordinator?
    private var onCapture: ((CaptureMode) -> Void)?

    /// 外部からセット（ClicherApp から呼ばれる）
    func configure(
        appState: AppState,
        captureCoordinator: CaptureCoordinator,
        onCapture: @escaping (CaptureMode) -> Void
    ) {
        self.appState = appState
        self.captureCoordinator = captureCoordinator
        self.onCapture = onCapture

        let hud = CaptureHUDWindow(appState: appState)
        hud.onModeSelected = onCapture
        self.hudWindow = hud

        // ⌘⇧A → Lark 風キャプチャ（画面暗転 + モードタブ + エリア選択）
        HotkeyManager.shared.onHotkeyPressed = { @MainActor [weak self] in
            self?.captureCoordinator?.startCaptureWithModeBar()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
