import SwiftUI
import SharedModels
import Utilities

/// メニューバーのドロップダウンメニュー内容
public struct MenuBarView: View {
    public let appState: AppState
    public let permissionManager: PermissionManager
    public let loginItemManager: LoginItemManager
    public let onCapture: (CaptureMode) -> Void
    public var onShowHistory: (() -> Void)?

    public init(
        appState: AppState,
        permissionManager: PermissionManager,
        loginItemManager: LoginItemManager,
        onCapture: @escaping (CaptureMode) -> Void,
        onShowHistory: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.permissionManager = permissionManager
        self.loginItemManager = loginItemManager
        self.onCapture = onCapture
        self.onShowHistory = onShowHistory
    }

    public var body: some View {
        Group {
            // キャプチャセクション
            Section("キャプチャ") {
                ForEach(CaptureMode.availableModes) { mode in
                    Button {
                        onCapture(mode)
                    } label: {
                        Label(mode.label, systemImage: mode.systemImage)
                    }
                }
            }

            Divider()

            // 権限セクション
            Section {
                let srIcon = permissionManager.hasScreenRecordingPermission
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
                let axIcon = permissionManager.hasAccessibilityPermission
                    ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"

                Button {
                    permissionManager.openScreenRecordingSettings()
                } label: {
                    Label("Screen Recording", systemImage: srIcon)
                }

                Button {
                    permissionManager.openAccessibilitySettings()
                } label: {
                    Label("Accessibility", systemImage: axIcon)
                }
            }

            Divider()

            // 設定セクション
            if let onShowHistory {
                Button {
                    onShowHistory()
                } label: {
                    Label(L10n.captureHistory, systemImage: "clock.arrow.circlepath")
                }
            }

            Button {
                NSApplication.shared.activate(ignoringOtherApps: true)
                // SettingsLink は MenuBarExtra 内で動作しないため直接アクションを送る
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } label: {
                Label(L10n.settings, systemImage: "gear")
            }
            .keyboardShortcut(",")

            Button(L10n.about) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                NSApplication.shared.orderFrontStandardAboutPanel()
            }

            Button(L10n.quit) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
