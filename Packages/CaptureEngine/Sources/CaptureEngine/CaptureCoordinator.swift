import ScreenCaptureKit
import AppKit
import OSLog
import Observation
import SharedModels
import Utilities

/// キャプチャフロー全体を管理するコーディネーター
/// モード選択 → キャプチャ実行 → 結果ハンドリング
@Observable
@MainActor
public final class CaptureCoordinator {
    /// キャプチャ中かどうか
    public private(set) var isCapturing = false

    /// カウントダウン中かどうか
    public private(set) var isCountingDown = false

    /// カウントダウン残り秒数
    public private(set) var countdownRemaining = 0

    /// 最後のキャプチャ結果
    public private(set) var lastResult: CaptureResult?

    /// キャプチャ完了時のコールバック
    public var onCaptureComplete: ((CaptureResult) -> Void)?

    /// カウントダウン開始時のコールバック（UI表示用）
    public var onCountdownTick: ((Int) -> Void)?

    /// 録画中かどうか
    public private(set) var isRecording = false

    /// スクロールキャプチャセッション
    public private(set) var scrollSession: ScrollCaptureSession?

    /// 画面録画セッション
    public private(set) var recordingSession: ScreenRecordingSession?

    /// インラインアノテーションオーバーレイ
    public private(set) var inlineAnnotate: InlineAnnotateOverlay?

    private let captureService: ScreenCaptureServiceProtocol
    private var countdownOverlay: CountdownOverlay?

    public init(captureService: ScreenCaptureServiceProtocol = ScreenCaptureService()) {
        self.captureService = captureService
    }

    /// 指定モードでキャプチャを開始（タイマー付き）
    public func startCapture(mode: CaptureMode, delay: TimerDelay = .none) {
        guard !isCapturing, !isCountingDown else { return }

        if delay != .none {
            startCountdown(seconds: delay.rawValue) {
                self.executeCapture(mode: mode)
            }
        } else {
            executeCapture(mode: mode)
        }
    }

    // MARK: - Countdown

    private func startCountdown(seconds: Int, completion: @escaping () -> Void) {
        isCountingDown = true
        countdownRemaining = seconds

        let overlay = CountdownOverlay()
        overlay.show(seconds: seconds)
        countdownOverlay = overlay

        Task {
            for remaining in stride(from: seconds, through: 1, by: -1) {
                countdownRemaining = remaining
                onCountdownTick?(remaining)
                overlay.update(remaining: remaining)
                try? await Task.sleep(for: .seconds(1))
            }
            countdownRemaining = 0
            isCountingDown = false
            overlay.dismiss()
            countdownOverlay = nil
            completion()
        }
    }

    private func executeCapture(mode: CaptureMode) {
        Task {
            switch mode {
            case .area:
                await startAreaCapture()
            case .window:
                await startWindowCapture()
            case .fullscreen:
                await startFullscreenCapture()
            case .ocr:
                await startOCRCapture()
            case .scroll:
                await startScrollCapture()
            case .recording:
                await startRecording()
            }
        }
    }

    // MARK: - Area Capture

    private func startAreaCapture() async {
        isCapturing = true

        // エリア選択オーバーレイを表示して範囲取得
        guard let selectedRect = await AreaSelectionOverlay.selectArea() else {
            Logger.capture.info("エリア選択がキャンセルされました")
            isCapturing = false
            return
        }

        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }

            let image = try await captureService.captureArea(rect: selectedRect, display: display)

            // ScreenCaptureKit 座標（左上原点）→ macOS 座標（左下原点）に変換
            let screenHeight = NSScreen.main?.frame.height ?? CGFloat(display.height)
            let macRect = CGRect(
                x: selectedRect.origin.x,
                y: screenHeight - selectedRect.origin.y - selectedRect.height,
                width: selectedRect.width,
                height: selectedRect.height
            )

            // インラインアノテーションを表示
            let overlay = InlineAnnotateOverlay()
            overlay.onComplete = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .area, captureRect: selectedRect)
                lastResult = result
                onCaptureComplete?(result)
                inlineAnnotate = nil
                isCapturing = false
            }
            overlay.onSave = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .area, captureRect: selectedRect)
                lastResult = result
                onCaptureComplete?(result)
                inlineAnnotate = nil
                isCapturing = false
            }
            overlay.onCancel = { [weak self] in
                self?.inlineAnnotate = nil
                self?.isCapturing = false
            }
            inlineAnnotate = overlay
            overlay.show(image: image, screenRect: macRect)

        } catch {
            Logger.capture.error("エリアキャプチャ失敗: \(error)")
            isCapturing = false
        }
    }

    // MARK: - Window Capture

    private func startWindowCapture() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let content = try await captureService.availableContent()

            // ウィンドウ選択オーバーレイを表示
            guard let selectedWindow = await WindowSelectionOverlay.selectWindow(
                from: content.windows
            ) else {
                Logger.capture.info("ウィンドウ選択がキャンセルされました")
                return
            }

            nonisolated(unsafe) let unsafeWindow = selectedWindow
            let image = try await captureService.captureWindow(unsafeWindow)
            let result = CaptureResult(
                image: image,
                mode: .window,
                captureRect: selectedWindow.frame
            )
            lastResult = result
            onCaptureComplete?(result)
        } catch {
            Logger.capture.error("ウィンドウキャプチャ失敗: \(error)")
        }
    }

    // MARK: - Fullscreen Capture

    private func startFullscreenCapture() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                return
            }

            let image = try await captureService.captureFullscreen(display: display)
            let result = CaptureResult(
                image: image,
                mode: .fullscreen,
                captureRect: CGRect(
                    x: 0, y: 0,
                    width: display.width, height: display.height
                )
            )
            lastResult = result
            onCaptureComplete?(result)
        } catch {
            Logger.capture.error("フルスクリーンキャプチャ失敗: \(error)")
        }
    }

    // MARK: - OCR Capture

    private func startOCRCapture() async {
        isCapturing = true
        defer { isCapturing = false }

        // エリア選択でOCR対象範囲を指定
        guard let selectedRect = await AreaSelectionOverlay.selectArea() else {
            Logger.capture.info("OCR エリア選択がキャンセルされました")
            return
        }

        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                return
            }

            let image = try await captureService.captureArea(rect: selectedRect, display: display)
            let result = CaptureResult(image: image, mode: .ocr, captureRect: selectedRect)
            lastResult = result

            // OCR 実行してクリップボードにコピー
            await OCRService.performOCRAndCopy(from: image)

            onCaptureComplete?(result)
        } catch {
            Logger.capture.error("OCR キャプチャ失敗: \(error)")
        }
    }

    // MARK: - Scroll Capture

    private func startScrollCapture() async {
        isCapturing = true

        let session = ScrollCaptureSession(captureService: captureService)
        session.onComplete = { [weak self] image in
            guard let self else { return }
            let result = CaptureResult(image: image, mode: .scroll)
            lastResult = result
            onCaptureComplete?(result)
            isCapturing = false
        }
        scrollSession = session
        await session.start()
    }

    /// スクロールキャプチャの追加フレームを取得
    public func captureScrollFrame() async {
        await scrollSession?.captureFrame()
    }

    /// スクロールキャプチャを完了
    public func finishScrollCapture() {
        _ = scrollSession?.finish()
        scrollSession = nil
    }

    /// スクロールキャプチャをキャンセル
    public func cancelScrollCapture() {
        scrollSession?.cancel()
        scrollSession = nil
        isCapturing = false
    }

    // MARK: - Screen Recording

    private func startRecording() async {
        isRecording = true

        let session = ScreenRecordingSession()
        session.onComplete = { [weak self] url in
            Logger.capture.info("録画ファイル: \(url.path)")
            self?.isRecording = false
        }
        recordingSession = session

        do {
            try await session.start()
        } catch {
            Logger.capture.error("録画開始失敗: \(error)")
            isRecording = false
            recordingSession = nil
        }
    }

    /// 録画を停止
    public func stopRecording() async {
        await recordingSession?.stop()
        recordingSession = nil
        isRecording = false
    }
}
