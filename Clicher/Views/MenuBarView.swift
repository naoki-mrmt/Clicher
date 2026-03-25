import SwiftUI

/// メニューバーのドロップダウンメニュー内容
struct MenuBarView: View {
    let appState: AppState
    let permissionManager: PermissionManager
    let loginItemManager: LoginItemManager
    let onCapture: (CaptureMode) -> Void

    var body: some View {
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
            SettingsLink {
                Label("設定...", systemImage: "gear")
            }
            .keyboardShortcut(",")

            Button("Clicher について") {
                NSApplication.shared.orderFrontStandardAboutPanel()
            }

            Button("終了") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
