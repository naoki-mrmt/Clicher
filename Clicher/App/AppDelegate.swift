import AppKit
import ServiceManagement

/// AppKit統合用のAppDelegate
/// グローバルホットキー、ログイン時起動の管理
final class AppDelegate: NSObject, NSApplicationDelegate {
    let hotkeyManager = HotkeyManager()

    var onAreaCapture: (() -> Void)?
    var onWindowCapture: (() -> Void)?
    var onFullscreenCapture: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupHotkeys()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyManager.stop()
    }

    // MARK: - Hotkey Setup

    private func setupHotkeys() {
        hotkeyManager.onAreaCapture = { [weak self] in
            self?.onAreaCapture?()
        }
        hotkeyManager.onWindowCapture = { [weak self] in
            self?.onWindowCapture?()
        }
        hotkeyManager.onFullscreenCapture = { [weak self] in
            self?.onFullscreenCapture?()
        }
        hotkeyManager.start()
    }

    // MARK: - Login Item

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // ログイン項目の設定に失敗した場合は静かに無視
        }
    }
}
