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
    private var permissionManager: PermissionManager?
    private var onCapture: ((CaptureMode) -> Void)?

    /// 外部からセット（ClicherApp から呼ばれる）
    func configure(
        appState: AppState,
        captureCoordinator: CaptureCoordinator,
        permissionManager: PermissionManager,
        appSettings: AppSettings,
        onCapture: @escaping (CaptureMode) -> Void
    ) {
        self.appState = appState
        self.captureCoordinator = captureCoordinator
        self.permissionManager = permissionManager
        self.onCapture = onCapture

        // カスタムホットキー設定を適用
        HotkeyManager.shared.configure(
            keyCode: appSettings.hotkeyKeyCode,
            modifiers: appSettings.hotkeyModifiers
        )

        let hud = CaptureHUDWindow(appState: appState)
        hud.onModeSelected = onCapture
        self.hudWindow = hud

        // ⌘⇧A → Lark 風キャプチャ（画面暗転 + モードタブ + エリア選択）
        HotkeyManager.shared.onHotkeyPressed = { @MainActor [weak self] in
            guard let self, let pm = self.permissionManager else { return }
            pm.checkScreenRecording()
            guard pm.hasScreenRecordingPermission else {
                pm.requestScreenRecording()
                return
            }
            self.captureCoordinator?.startCaptureWithModeBar()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        HotkeyManager.shared.register()
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }
}
