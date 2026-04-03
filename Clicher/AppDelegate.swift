import AppKit
import SwiftUI
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

    /// SwiftUI Window を開くためのコールバック（ClicherApp から設定）
    var openPermissionGuide: (() -> Void)?

    /// configureIfNeeded() を起動時に呼ぶためのコールバック（ClicherApp から設定）
    var triggerConfigure: (() -> Void)?

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

        // configure() 完了後にタップを再登録して最高優先度を確保（Lark等より優先）
        HotkeyManager.shared.reregister()

        Logger.hotkey.info("ホットキー configure 完了、タップ再登録済み")
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 起動直後にタップを登録（デフォルト ⌘⇧A でイベントを横取り → Lark をブロック）
        // コールバックは configure() で後から設定されるが、タップ自体は先に存在させる
        HotkeyManager.shared.register()

        // configureIfNeeded() を起動時に呼ぶ
        // MenuBarExtra の onAppear は遅延発火するため、ここから直接トリガー
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.triggerConfigure?()
        }

        // 権限不足なら権限ガイドウィンドウを表示
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self, let pm = self.permissionManager else { return }
            pm.checkAll()
            if !pm.hasScreenRecordingPermission || !pm.hasAccessibilityPermission {
                self.showPermissionGuideWindow()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        HotkeyManager.shared.unregister()
    }

    // MARK: - Permission Guide Window (AppKit)

    private var permissionGuideWindow: NSWindow?

    private func showPermissionGuideWindow() {
        guard let pm = permissionManager else { return }

        let view = PermissionGuideView(
            permissionManager: pm,
            onDismiss: { [weak self] in
                if pm.hasAccessibilityPermission {
                    HotkeyManager.shared.register()
                }
                self?.permissionGuideWindow?.close()
                self?.permissionGuideWindow = nil
            }
        )

        let hostingView = NSHostingView(rootView: view)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 420, height: 480)),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Clicher"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        permissionGuideWindow = window
    }
}
