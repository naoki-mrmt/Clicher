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
    @State private var presetStore: BrandPresetStore?
    @State private var isConfigured = false

    var body: some Scene {
        // AppDelegate に configureIfNeeded トリガーを渡す（起動時に呼ばれる）
        let _ = setupTriggerConfigure()

        // メニューバー（録画中はアイコン変更）
        MenuBarExtra(
            "Clicher",
            systemImage: captureCoordinator.isRecording ? "record.circle.fill" : "camera.fill"
        ) {
            MenuBarContent(
                appState: appState,
                permissionManager: permissionManager,
                loginItemManager: loginItemManager,
                captureCoordinator: captureCoordinator,
                onCapture: handleCapture,
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

        // 権限ガイドウィンドウ
        Window(L10n.permissionSettings, id: "permission-guide") {
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

        // ホットキー登録失敗時のトースト通知
        HotkeyManager.shared.onRegistrationFailed = {
            toastOverlay.show(L10n.hotkeyRegistrationFailed, style: .error, duration: 5)
        }

        // キャプチャ完了 → Quick Access Overlay を表示
        captureCoordinator.onCaptureComplete = { result in
            quickAccessOverlay.show(result: result)
        }

        // OCR 結果 → パネル表示（Lark 風テキスト確認 UI）
        let ocrPanel = OCRResultPanel()
        captureCoordinator.onOCRResult = { text, _ in
            ocrPanel.show(text: text) {
                toastOverlay.show(L10n.copied, style: .success, duration: 2)
            }
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

        // エラー通知 → トースト表示
        captureCoordinator.onError = { message in
            toastOverlay.show(message, style: .error)
        }

        // 長時間処理のローディング表示
        captureCoordinator.onProcessingStart = { message in
            toastOverlay.show(message, style: .info, duration: 30)
        }
        captureCoordinator.onProcessingEnd = {
            toastOverlay.dismiss()
        }

        // 録画開始/停止 → RecordingIndicator 表示（録画範囲をハイライト）
        var recordingIndicator: RecordingIndicator?
        captureCoordinator.onRecordingStarted = { screenRect in
            let indicator = RecordingIndicator()
            indicator.onStop = {
                Task { await captureCoordinator.stopRecording() }
            }
            indicator.show(screenRect: screenRect)
            recordingIndicator = indicator
        }
        captureCoordinator.onRecordingStopped = {
            recordingIndicator?.dismiss()
            recordingIndicator = nil
        }

        // 録画完了 → 選択パネルを表示（保存 / コピー / Finder で表示）
        let recordingCompletePanel = RecordingCompletePanel()
        captureCoordinator.onRecordingComplete = { [appSettings] url in
            recordingCompletePanel.onSave = { videoURL in
                let saveDir = appSettings.saveDirectory
                let fileName = "Clicher_Recording_\(Int(Date().timeIntervalSince1970)).mp4"
                let destination = saveDir.appendingPathComponent(fileName)
                do {
                    try FileManager.default.moveItem(at: videoURL, to: destination)
                    toastOverlay.show(L10n.saved(fileName), style: .success, duration: 3)
                } catch {
                    Logger.app.error("録画ファイルの移動に失敗: \(error)")
                    toastOverlay.show(L10n.saveFailed, style: .error)
                }
            }
            recordingCompletePanel.onCopy = { videoURL in
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects([videoURL as NSURL])
                toastOverlay.show(L10n.copied, style: .success, duration: 2)
            }
            recordingCompletePanel.onReveal = { videoURL in
                NSWorkspace.shared.activateFileViewerSelecting([videoURL])
            }
            recordingCompletePanel.onConvertGIF = { [appSettings] videoURL in
                toastOverlay.show(L10n.convertToGIF + "...", style: .info, duration: 30)
                Task {
                    do {
                        let gifURL = try await GIFConverter.convert(videoURL: videoURL, width: 640)
                        let saveDir = appSettings.saveDirectory
                        let fileName = gifURL.lastPathComponent
                        let destination = saveDir.appendingPathComponent(fileName)
                        try? FileManager.default.moveItem(at: gifURL, to: destination)
                        let finalURL = FileManager.default.fileExists(atPath: destination.path) ? destination : gifURL
                        toastOverlay.show(L10n.saved(finalURL.lastPathComponent), style: .success, duration: 3)
                        NSWorkspace.shared.activateFileViewerSelecting([finalURL])
                    } catch {
                        Logger.app.error("GIF 変換失敗: \(error)")
                        toastOverlay.show("GIF 変換失敗: \(error.localizedDescription)", style: .error)
                    }
                }
            }
            recordingCompletePanel.onClose = {}
            recordingCompletePanel.show(videoURL: url)
        }

        // Annotate 完了 → クリップボードにコピー + トースト通知
        annotateWindow.onComplete = { image in
            ImageExporter.copyToClipboard(image)
            toastOverlay.show(L10n.copied, style: .success, duration: 2)
        }
        annotateWindow.onError = { message in
            toastOverlay.show(message, style: .error)
        }

        appDelegate.configure(
            appState: appState,
            captureCoordinator: captureCoordinator,
            permissionManager: permissionManager,
            appSettings: appSettings,
            onCapture: handleCapture
        )
        permissionManager.checkAll()

        Logger.app.info("Clicher 初期化完了")
    }

    /// AppDelegate.triggerConfigure を設定する（body 評価時に1度だけ実行）
    private func setupTriggerConfigure() {
        if appDelegate.triggerConfigure == nil {
            appDelegate.triggerConfigure = { [self] in
                configureIfNeeded()
            }
        }
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
    let captureCoordinator: CaptureCoordinator
    let onCapture: (CaptureMode) -> Void
    let configureIfNeeded: () -> Void
    @Binding var isPermissionGuideVisible: Bool

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        MenuBarView(
            appState: appState,
            permissionManager: permissionManager,
            loginItemManager: loginItemManager,
            onCapture: onCapture,
            isRecording: captureCoordinator.isRecording,
            onStopRecording: {
                Task { await captureCoordinator.stopRecording() }
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
