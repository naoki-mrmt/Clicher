import ScreenCaptureKit
import AppKit

/// キャプチャフロー全体を管理するコーディネーター
@Observable
final class CaptureCoordinator {
    let captureService: ScreenCaptureService
    let permissionManager: PermissionManager
    let settings: AppSettings

    var lastCaptureResult: CaptureResult?
    var isCapturing = false
    var showOverlay = false
    var showAnnotateEditor = false
    var captureError: CaptureError?

    // Area selection state
    var isSelectingArea = false
    var isSelectingWindow = false

    init(
        captureService: ScreenCaptureService = ScreenCaptureService(),
        permissionManager: PermissionManager = PermissionManager(),
        settings: AppSettings = AppSettings()
    ) {
        self.captureService = captureService
        self.permissionManager = permissionManager
        self.settings = settings
    }

    // MARK: - Capture Actions

    /// エリアキャプチャを開始
    func startAreaCapture() {
        guard !isCapturing else { return }
        isSelectingArea = true
    }

    /// ウィンドウキャプチャを開始
    func startWindowCapture() {
        guard !isCapturing else { return }
        isSelectingWindow = true
    }

    /// フルスクリーンキャプチャを実行
    func captureFullscreen() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                captureError = .noDisplayFound
                return
            }
            let image = try await captureService.captureFullscreen(display: display)
            let result = CaptureResult(
                image: image,
                captureMode: .fullscreen,
                capturedAt: .now,
                sourceRect: CGRect(x: 0, y: 0, width: display.width, height: display.height)
            )
            lastCaptureResult = result
            showQuickAccessOverlay()
        } catch {
            captureError = .captureFailedGeneric
        }
    }

    /// 選択されたエリアをキャプチャ
    func captureArea(rect: CGRect) async {
        isSelectingArea = false
        isCapturing = true
        defer { isCapturing = false }

        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                captureError = .noDisplayFound
                return
            }
            let image = try await captureService.captureArea(rect: rect, display: display)
            let result = CaptureResult(
                image: image,
                captureMode: .area,
                capturedAt: .now,
                sourceRect: rect
            )
            lastCaptureResult = result
            showQuickAccessOverlay()
        } catch {
            captureError = .captureFailedGeneric
        }
    }

    /// 選択されたウィンドウをキャプチャ
    func captureWindow(_ window: SCWindow) async {
        isSelectingWindow = false
        isCapturing = true
        defer { isCapturing = false }

        do {
            let image = try await captureService.captureWindow(window)
            let result = CaptureResult(
                image: image,
                captureMode: .window,
                capturedAt: .now,
                sourceRect: window.frame
            )
            lastCaptureResult = result
            showQuickAccessOverlay()
        } catch {
            captureError = .captureFailedGeneric
        }
    }

    // MARK: - Overlay

    /// キャプチャ完了後に Overlay を表示
    private func showQuickAccessOverlay() {
        guard let result = lastCaptureResult, settings.showOverlayAfterCapture else { return }
        showOverlay = true
        OverlayWindowController.shared.show(
            captureResult: result,
            coordinator: self,
            position: settings.overlayPosition,
            autoCloseDelay: settings.overlayAutoCloseDelay
        )
    }

    // MARK: - Post-capture Actions

    /// キャプチャ結果をクリップボードにコピー
    func copyToClipboard() {
        lastCaptureResult?.copyToClipboard()
        showOverlay = false
        OverlayWindowController.shared.dismiss()
    }

    /// キャプチャ結果をファイルに保存
    func saveToFile() {
        guard let result = lastCaptureResult else { return }
        let fileName = settings.fileNamePattern.generateName()
        let ext = settings.defaultExportFormat.fileExtension
        let url = settings.defaultSaveDirectory.appending(path: "\(fileName).\(ext)")
        do {
            try result.save(to: url, format: settings.defaultExportFormat)
            showOverlay = false
            OverlayWindowController.shared.dismiss()
        } catch {
            captureError = .exportFailed
        }
    }

    /// Annotateエディタを開く
    func openAnnotateEditor() {
        showOverlay = false
        showAnnotateEditor = true
    }

    /// Overlay を閉じる
    func dismissOverlay() {
        showOverlay = false
        OverlayWindowController.shared.dismiss()
    }

    /// Annotate エディタを閉じる
    func dismissAnnotateEditor() {
        showAnnotateEditor = false
    }
}
