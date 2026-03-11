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
            if settings.showOverlayAfterCapture {
                showOverlay = true
            }
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
            if settings.showOverlayAfterCapture {
                showOverlay = true
            }
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
            if settings.showOverlayAfterCapture {
                showOverlay = true
            }
        } catch {
            captureError = .captureFailedGeneric
        }
    }

    // MARK: - Post-capture Actions

    /// キャプチャ結果をクリップボードにコピー
    func copyToClipboard() {
        lastCaptureResult?.copyToClipboard()
        showOverlay = false
    }

    /// キャプチャ結果をファイルに保存
    func saveToFile() {
        guard let result = lastCaptureResult else { return }
        let fileName = settings.fileNamePattern.generateName()
        let ext = settings.defaultExportFormat == .png ? "png" : "jpg"
        let url = settings.defaultSaveDirectory.appending(path: "\(fileName).\(ext)")
        do {
            try result.save(to: url, format: settings.defaultExportFormat)
            showOverlay = false
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
    }

    /// Annotate エディタを閉じる
    func dismissAnnotateEditor() {
        showAnnotateEditor = false
    }
}
