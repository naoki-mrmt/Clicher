import SwiftUI
import SharedModels
import Utilities

/// メニューバーのドロップダウンメニュー内容
public struct MenuBarView: View {
    public let appState: AppState
    public let permissionManager: PermissionManager
    public let loginItemManager: LoginItemManager
    public let onCapture: (CaptureMode) -> Void
    public let isRecording: Bool
    public var onStopRecording: (() -> Void)?

    public init(
        appState: AppState,
        permissionManager: PermissionManager,
        loginItemManager: LoginItemManager,
        onCapture: @escaping (CaptureMode) -> Void,
        isRecording: Bool = false,
        onStopRecording: (() -> Void)? = nil
    ) {
        self.appState = appState
        self.permissionManager = permissionManager
        self.loginItemManager = loginItemManager
        self.onCapture = onCapture
        self.isRecording = isRecording
        self.onStopRecording = onStopRecording
    }

    public var body: some View {
        Group {
            // 録画停止ボタン（録画中のみ表示）
            if isRecording {
                Button {
                    onStopRecording?()
                } label: {
                    Label(L10n.stopRecording, systemImage: "stop.circle.fill")
                        .foregroundStyle(.red)
                }
                Divider()
            }

            // キャプチャセクション
            Section(L10n.capture) {
                ForEach(CaptureMode.allCases) { mode in
                    Button {
                        onCapture(mode)
                    } label: {
                        Label(mode.label, systemImage: mode.systemImage)
                    }
                    .disabled(isRecording)
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
                    Label(L10n.screenRecordingLabel, systemImage: srIcon)
                }

                Button {
                    permissionManager.openAccessibilitySettings()
                } label: {
                    Label(L10n.accessibilityLabel, systemImage: axIcon)
                }
            }

            Divider()

            // 設定セクション
            // SettingsLink を SimultaneousGesture でラップしてアプリを最前面化
            // （メニューバーアプリは LSUIElement のため、Settings を開いただけでは前面に出ない）
            SettingsLink {
                Label(L10n.settings, systemImage: "gear")
            }
            .keyboardShortcut(",")
            .simultaneousGesture(TapGesture().onEnded {
                NSApplication.shared.activate(ignoringOtherApps: true)
            })

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
