import SwiftUI
import OSLog

@main
struct ClicherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var appSettings = AppSettings()
    @State private var permissionManager = PermissionManager()
    @State private var loginItemManager = LoginItemManager()
    @State private var captureCoordinator = CaptureCoordinator()
    @State private var quickAccessOverlay = QuickAccessOverlay()
    @State private var annotateWindow = AnnotateWindow()
    @State private var isConfigured = false

    var body: some Scene {
        // メニューバー
        MenuBarExtra("Clicher", systemImage: "camera.viewfinder") {
            MenuBarView(
                appState: appState,
                permissionManager: permissionManager,
                loginItemManager: loginItemManager,
                onCapture: handleCapture
            )
            .onAppear {
                configureIfNeeded()
            }
        }

        // 設定ウィンドウ
        Settings {
            SettingsView(
                settings: appSettings,
                permissionManager: permissionManager,
                loginItemManager: loginItemManager
            )
        }

        // 権限ガイドウィンドウ
        Window("権限設定", id: "permission-guide") {
            PermissionGuideView(
                permissionManager: permissionManager,
                onDismiss: {
                    if permissionManager.hasAccessibilityPermission {
                        HotkeyManager.shared.register()
                    }
                }
            )
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        isConfigured = true

        // キャプチャ完了 → Quick Access Overlay を表示
        captureCoordinator.onCaptureComplete = { result in
            quickAccessOverlay.show(result: result)
        }

        // Quick Access Overlay のアクション
        quickAccessOverlay.onSave = { result in
            _ = ImageExporter.saveToFile(result.image, directory: appSettings.saveDirectory)
        }
        quickAccessOverlay.onCopy = { result in
            ImageExporter.copyToClipboard(result.image)
        }
        quickAccessOverlay.onEdit = { result in
            annotateWindow.open(with: result)
        }

        // Annotate 完了 → クリップボードにコピー
        annotateWindow.onComplete = { image in
            ImageExporter.copyToClipboard(image)
        }

        appDelegate.configure(appState: appState, onCapture: handleCapture)
        permissionManager.checkAll()
        Logger.app.info("Clicher 初期化完了")
    }

    private func handleCapture(_ mode: CaptureMode) {
        permissionManager.checkAll()
        guard permissionManager.hasScreenRecordingPermission else {
            permissionManager.requestScreenRecording()
            return
        }

        appState.selectedCaptureMode = mode
        captureCoordinator.startCapture(mode: mode)
    }
}
