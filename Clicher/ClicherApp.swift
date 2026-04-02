import SwiftUI
import OSLog
import SharedModels
import Utilities
import CaptureEngine
import AnnotateEngine
import OverlayUI

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
    @State private var floatingManager = FloatingScreenshotManager()
    @State private var toastOverlay = ToastOverlay()
    @State private var historyStore = CaptureHistoryStore()
    @State private var presetStore: BrandPresetStore?
    @State private var isConfigured = false

    var body: some Scene {
        // メニューバー（録画中はアイコン変更）
        MenuBarExtra(
            "Clicher",
            systemImage: captureCoordinator.isRecording ? "record.circle" : "camera.viewfinder"
        ) {
            MenuBarContent(
                appState: appState,
                permissionManager: permissionManager,
                loginItemManager: loginItemManager,
                onCapture: handleCapture,
                historyStore: historyStore,
                configureIfNeeded: configureIfNeeded,
                isPermissionGuideVisible: $appState.isPermissionGuideVisible
            )
        }

        // 設定ウィンドウ
        Settings {
            SettingsView(
                settings: appSettings,
                permissionManager: permissionManager,
                loginItemManager: loginItemManager,
                presetStore: presetStore
            )
        }

        // キャプチャ履歴ウィンドウ
        Window("キャプチャ履歴", id: "capture-history") {
            CaptureHistoryView(store: historyStore)
        }
        .windowResizability(.contentSize)

        // 権限ガイドウィンドウ
        Window("権限設定", id: "permission-guide") {
            PermissionGuideView(
                permissionManager: permissionManager,
                onDismiss: {
                    appState.isPermissionGuideVisible = false
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

        // BrandPresetStore を遅延初期化
        if presetStore == nil {
            presetStore = BrandPresetStore()
        }

        // Quick Access Overlay に設定を渡す
        quickAccessOverlay.settings = appSettings

        // キャプチャ完了 → Quick Access Overlay を表示 + 履歴に追加
        captureCoordinator.onCaptureComplete = { result in
            quickAccessOverlay.show(result: result)
            historyStore.add(image: result.image, mode: result.mode)
        }

        // Quick Access Overlay のアクション
        quickAccessOverlay.onSave = { result in
            if let url = ImageExporter.saveToFile(result.image, directory: appSettings.saveDirectory) {
                toastOverlay.show(L10n.saved(url.lastPathComponent), style: .success, duration: 2)
            } else {
                toastOverlay.show(L10n.saveFailed, style: .error)
            }
        }
        quickAccessOverlay.onCopy = { result in
            ImageExporter.copyToClipboard(result.image)
            toastOverlay.show(L10n.copied, style: .success, duration: 2)
        }
        quickAccessOverlay.onEdit = { result in
            annotateWindow.open(with: result)
        }
        quickAccessOverlay.onPin = { result in
            floatingManager.pin(result: result)
        }

        // デフォルトブランドプリセットを Annotate に適用
        annotateWindow.defaultPreset = presetStore?.defaultPreset()

        // スクロールキャプチャ操作 UI
        captureCoordinator.onScrollCaptureStarted = {
            let controls = ScrollCaptureControls()
            controls.onCaptureFrame = {
                Task { await captureCoordinator.captureScrollFrame() }
            }
            controls.onFinish = {
                captureCoordinator.finishScrollCapture()
            }
            controls.onCancel = {
                captureCoordinator.cancelScrollCapture()
            }
            controls.show()
        }

        // エラー通知 → トースト表示
        captureCoordinator.onError = { message in
            toastOverlay.show(message, style: .error)
        }

        // Annotate 完了 → クリップボードにコピー
        annotateWindow.onComplete = { image in
            ImageExporter.copyToClipboard(image)
        }

        appDelegate.configure(
            appState: appState,
            captureCoordinator: captureCoordinator,
            permissionManager: permissionManager,
            onCapture: handleCapture
        )
        permissionManager.checkAll()

        // 権限が不足していれば権限ガイドを表示
        if !permissionManager.hasScreenRecordingPermission || !permissionManager.hasAccessibilityPermission {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let app = NSApp {
                    app.activate(ignoringOtherApps: true)
                }
                appState.isPermissionGuideVisible = true
            }
        }

        Logger.app.info("Clicher 初期化完了")
    }

    private func handleCapture(_ mode: CaptureMode) {
        permissionManager.checkAll()
        guard permissionManager.hasScreenRecordingPermission else {
            permissionManager.requestScreenRecording()
            return
        }

        appState.selectedCaptureMode = mode
        captureCoordinator.startCapture(mode: mode, delay: appState.timerDelay)
    }
}

// MARK: - Menu Bar Content (with @Environment access)

private struct MenuBarContent: View {
    let appState: AppState
    let permissionManager: PermissionManager
    let loginItemManager: LoginItemManager
    let onCapture: (CaptureMode) -> Void
    let historyStore: CaptureHistoryStore
    let configureIfNeeded: () -> Void
    @Binding var isPermissionGuideVisible: Bool

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarView(
            appState: appState,
            permissionManager: permissionManager,
            loginItemManager: loginItemManager,
            onCapture: onCapture,
            onShowHistory: {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "capture-history")
            }
        )
        .onAppear {
            configureIfNeeded()
        }
        .onChange(of: isPermissionGuideVisible) { _, visible in
            if visible {
                openWindow(id: "permission-guide")
            }
        }
    }
}
