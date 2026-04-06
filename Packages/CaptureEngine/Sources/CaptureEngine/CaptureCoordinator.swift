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

    /// エラー発生時のコールバック（UI通知用）
    /// メッセージにはユーザー向けの説明 + デバッグ用の詳細を含む
    public var onError: ((String) -> Void)?

    /// 長時間処理の開始/終了コールバック（ローディング表示用）
    public var onProcessingStart: ((String) -> Void)?
    public var onProcessingEnd: (() -> Void)?

    /// 録画開始/停止コールバック（RecordingIndicator 表示用）
    public var onRecordingStarted: (() -> Void)?
    public var onRecordingStopped: (() -> Void)?

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
    private var countdownTask: Task<Void, Never>?

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
        countdownTask?.cancel()
        isCountingDown = true
        countdownRemaining = seconds

        let overlay = CountdownOverlay()
        overlay.show(seconds: seconds)
        countdownOverlay = overlay

        countdownTask = Task {
            for remaining in stride(from: seconds, through: 1, by: -1) {
                guard !Task.isCancelled else { break }
                countdownRemaining = remaining
                onCountdownTick?(remaining)
                overlay.update(remaining: remaining)
                try? await Task.sleep(for: .seconds(1))
            }
            guard !Task.isCancelled else {
                overlay.dismiss()
                countdownOverlay = nil
                isCountingDown = false
                countdownRemaining = 0
                return
            }
            countdownRemaining = 0
            isCountingDown = false
            overlay.dismiss()
            countdownOverlay = nil
            completion()
        }
    }

    private func executeCapture(mode: CaptureMode) {
        isCapturing = true
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
                // 録画はモードタブ経由で処理（startCaptureWithModeBar から呼ばれる）
                // メニューから直接呼ばれた場合は startCaptureWithModeBar にフォールバック
                isCapturing = false
                startCaptureWithModeBar()
                return
            }
        }
    }

    // MARK: - Lark-style Capture (Mode Bar + Area Selection)

    /// モードタブで選択中のモード（エリア選択中にモード変更可能）
    private var modeBarSelectedMode: CaptureMode = .area

    /// Lark 風キャプチャ: 画面暗転 + モードタブバー → 共通エリア選択 → モード別処理
    public func startCaptureWithModeBar() {
        guard !isCapturing, !isCountingDown else { return }
        isCapturing = true
        modeBarSelectedMode = .area

        let overlay = InlineAnnotateOverlay()
        overlay.onModeChanged = { [weak self] mode in
            // モード切替は状態更新のみ（エリア選択は継続）
            self?.modeBarSelectedMode = mode
        }
        overlay.onCancel = { [weak self] in
            self?.inlineAnnotate = nil
            self?.isCapturing = false
        }
        inlineAnnotate = overlay

        // 背景暗転 + モードタブを表示
        overlay.showModeTabOnly(currentMode: .area)

        // 共通エリア選択 → 完了後にモード別処理
        Task {
            await startModeBarCapture(overlay: overlay)
        }
    }

    /// モードタブ付きキャプチャの共通フロー
    private func startModeBarCapture(overlay: InlineAnnotateOverlay) async {
        // エリア選択中は dim とキーモニターを解除
        overlay.hideDim()
        overlay.removeKeyMonitor()

        let areaRect = await AreaSelectionOverlay.selectArea()

        guard let macRect = areaRect else {
            // ESC キャンセル
            overlay.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            return
        }

        // エリア選択完了時点のモードで分岐
        let mode = modeBarSelectedMode

        switch mode {
        case .area:
            await captureAreaAfterSelection(macRect: macRect, overlay: overlay)
        case .recording:
            await startRecordingAfterSelection(macRect: macRect, overlay: overlay)
        case .ocr:
            overlay.dismiss()
            inlineAnnotate = nil
            await startOCRAfterSelection(macRect: macRect)
        case .window:
            // ウィンドウキャプチャ: エリア選択結果は使わず、ウィンドウ選択 UI を表示
            overlay.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            await startWindowCapture()
        case .fullscreen:
            // フルスクリーン: エリア選択結果は使わず、即キャプチャ
            overlay.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            await startFullscreenCapture()
        case .scroll:
            // スクロール: エリア選択結果は使わず、独自フローへ
            overlay.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            await startScrollCapture()
        }
    }

    // MARK: - Area Capture (after mode bar selection)

    /// モードタブ経由でエリア選択済みの場合のキャプチャ処理
    private func captureAreaAfterSelection(macRect: CGRect, overlay: InlineAnnotateOverlay) async {
        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }

            // キャプチャ前にオーバーレイを非表示
            overlay.hideModeTab()
            overlay.hideDim()
            try await Task.sleep(for: .milliseconds(16))

            let image = try await captureService.captureArea(macRect: macRect, display: display)

            overlay.onComplete = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .area, captureRect: macRect)
                lastResult = result
                onCaptureComplete?(result)
                inlineAnnotate = nil
                isCapturing = false
            }
            overlay.onSave = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .area, captureRect: macRect)
                lastResult = result
                onCaptureComplete?(result)
                inlineAnnotate = nil
                isCapturing = false
            }
            overlay.onCancel = { [weak self] in
                self?.inlineAnnotate = nil
                self?.isCapturing = false
            }
            overlay.show(image: image, screenRect: macRect)

        } catch {
            let nsError = error as NSError
            Logger.capture.error("エリアキャプチャ失敗: domain=\(nsError.domain) code=\(nsError.code) \(error)")
            onError?("エリアキャプチャ失敗: [\(nsError.domain):\(nsError.code)] \(error.localizedDescription)")
            overlay.dismiss()
            inlineAnnotate = nil
            isCapturing = false
        }
    }

    /// モードタブ経由でエリア選択済みの場合の OCR 処理
    private func startOCRAfterSelection(macRect: CGRect) async {
        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }

            let image = try await captureService.captureArea(macRect: macRect, display: display)

            onProcessingStart?(L10n.processingOCR)
            let ocrResult = try await OCRService.recognizeText(from: image)
            onProcessingEnd?()

            if !ocrResult.isEmpty {
                let fullText: String
                if ocrResult.barcodes.isEmpty {
                    fullText = ocrResult.text
                } else {
                    let barcodeSection = ocrResult.barcodes.joined(separator: "\n")
                    fullText = ocrResult.text.isEmpty
                        ? barcodeSection
                        : "\(ocrResult.text)\n\n--- Barcodes ---\n\(barcodeSection)"
                }
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(fullText, forType: .string)
            }

            let result = CaptureResult(image: image, mode: .ocr, captureRect: macRect, ocrText: ocrResult.text)
            lastResult = result
            onCaptureComplete?(result)
        } catch {
            Logger.capture.error("OCR 失敗: \(error)")
            onError?("OCR 失敗: \(error.localizedDescription)")
        }
        isCapturing = false
    }

    /// モードタブ経由でエリア選択済みの場合の録画処理
    private func startRecordingAfterSelection(macRect: CGRect, overlay: InlineAnnotateOverlay) async {
        let screenHeight = ScreenUtilities.activeScreenFrame.height
        let sckRect = CGRect(
            x: macRect.origin.x,
            y: screenHeight - macRect.origin.y - macRect.height,
            width: macRect.width,
            height: macRect.height
        )

        var didStart = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            overlay.showRecordingReady(
                screenRect: macRect,
                onStart: {
                    didStart = true
                    continuation.resume()
                },
                onCancel: { [weak self] in
                    self?.inlineAnnotate = nil
                    self?.isCapturing = false
                    continuation.resume()
                }
            )
        }

        guard didStart else { return }

        // 全オーバーレイを消して録画開始
        overlay.dismiss()
        inlineAnnotate = nil

        isRecording = true

        let session = ScreenRecordingSession()
        session.onComplete = { [weak self] url in
            guard let self else { return }
            Logger.capture.info("録画ファイル: \(url.path)")
            isRecording = false
            isCapturing = false
            onRecordingStopped?()
        }
        session.onError = { [weak self] message in
            self?.onError?(message)
        }
        recordingSession = session

        do {
            try await session.start(sourceRect: sckRect)
            onRecordingStarted?()
        } catch {
            Logger.capture.error("録画開始失敗: \(error)")
            onError?("録画開始失敗: \(error.localizedDescription)")
            isRecording = false
            isCapturing = false
            recordingSession = nil
        }
    }

    // MARK: - Area Capture (standalone)

    private func startAreaCapture() async {
        // エリア選択中は dim とキーモニターを隠す（AreaSelectionOverlay が ESC を処理するため）
        inlineAnnotate?.hideDim()
        inlineAnnotate?.removeKeyMonitor()

        // エリア選択と SCShareableContent 取得を並行実行（速度改善）
        async let selectionTask = AreaSelectionOverlay.selectArea()
        async let contentTask = captureService.availableContent()

        guard let macRect = await selectionTask else {
            Logger.capture.info("エリア選択がキャンセルされました")
            _ = try? await contentTask
            inlineAnnotate?.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            return
        }

        do {
            let content = try await contentTask
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }

            Logger.capture.info("エリアキャプチャ: macRect=\(macRect.debugDescription) display=\(display.width)x\(display.height)")

            // キャプチャ前にすべての Clicher オーバーレイを非表示
            // CGWindowListCreateImage は画面上の全ウィンドウをキャプチャするため
            inlineAnnotate?.hideModeTab()
            inlineAnnotate?.hideDim()
            // ウィンドウサーバーに orderOut を反映させる最小待機
            try await Task.sleep(for: .milliseconds(16))

            // macOS 座標をそのまま渡す（座標変換は captureArea 内で行う）
            let image = try await captureService.captureArea(macRect: macRect, display: display)

            // インラインアノテーションを表示（macOS 座標をそのまま渡す）
            let overlay = inlineAnnotate ?? InlineAnnotateOverlay()
            overlay.onComplete = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .area, captureRect: macRect)
                lastResult = result
                onCaptureComplete?(result)
                inlineAnnotate = nil
                isCapturing = false
            }
            overlay.onSave = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .area, captureRect: macRect)
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
            let nsError = error as NSError
            Logger.capture.error("エリアキャプチャ失敗: domain=\(nsError.domain) code=\(nsError.code) \(error)")
            onError?("エリアキャプチャ失敗: [\(nsError.domain):\(nsError.code)] \(error.localizedDescription)")
            inlineAnnotate?.dismiss()
            inlineAnnotate = nil
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
            onError?("ウィンドウキャプチャ失敗: \(error.localizedDescription)")
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
            onError?("フルスクリーンキャプチャ失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - OCR Capture

    private func startOCRCapture() async {
        isCapturing = true
        defer { isCapturing = false }

        // エリア選択でOCR対象範囲を指定（macOS 座標で返る）
        guard let macRect = await AreaSelectionOverlay.selectArea() else {
            Logger.capture.info("OCR エリア選択がキャンセルされました")
            return
        }

        do {
            let content = try await captureService.availableContent()
            guard let display = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                return
            }

            // macOS 座標をそのまま渡す（座標変換は captureArea 内で行う）
            let image = try await captureService.captureArea(macRect: macRect, display: display)

            // OCR 実行してクリップボードにコピー
            onProcessingStart?(L10n.processingOCR)
            let ocrResult = try await OCRService.recognizeText(from: image)
            onProcessingEnd?()
            if !ocrResult.isEmpty {
                let fullText: String
                if ocrResult.barcodes.isEmpty {
                    fullText = ocrResult.text
                } else {
                    let barcodeSection = ocrResult.barcodes.joined(separator: "\n")
                    fullText = ocrResult.text.isEmpty
                        ? barcodeSection
                        : "\(ocrResult.text)\n\n--- Barcodes ---\n\(barcodeSection)"
                }
                await MainActor.run {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(fullText, forType: .string)
                }
            }

            let result = CaptureResult(
                image: image, mode: .ocr, captureRect: macRect,
                ocrText: ocrResult.text.isEmpty ? nil : ocrResult.text
            )
            lastResult = result
            onCaptureComplete?(result)
        } catch {
            Logger.capture.error("OCR キャプチャ失敗: \(error)")
            onError?("OCR キャプチャ失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - Scroll Capture

    /// スクロールキャプチャ操作 UI 表示のコールバック
    /// App 層で ScrollCaptureControls を表示するために使う
    public var onScrollCaptureStarted: (() -> Void)?

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

        // 初回フレーム取得後に操作 UI を表示
        if session.isCapturing {
            onScrollCaptureStarted?()
        }
    }

    /// スクロールキャプチャの追加フレームを取得
    public func captureScrollFrame() async {
        await scrollSession?.captureFrame()
    }

    /// スクロールキャプチャを完了
    public func finishScrollCapture() {
        onProcessingStart?(L10n.processingStitch)
        _ = scrollSession?.finish()
        scrollSession = nil
        onProcessingEnd?()
    }

    /// スクロールキャプチャをキャンセル
    public func cancelScrollCapture() {
        scrollSession?.cancel()
        scrollSession = nil
        isCapturing = false
    }

    /// プレースホルダー画像（録画完了時の通知用）
    private func createPlaceholderImage() -> CGImage {
        let ctx = CGContext(data: nil, width: 1, height: 1,
                           bitsPerComponent: 8, bytesPerRow: 0,
                           space: CGColorSpaceCreateDeviceRGB(),
                           bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
        return ctx?.makeImage() ?? CGContext(data: nil, width: 1, height: 1,
                                             bitsPerComponent: 8, bytesPerRow: 4,
                                             space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)!.makeImage()!
    }

    /// 録画を停止
    public func stopRecording() async {
        await recordingSession?.stop()
        recordingSession = nil
        isRecording = false
        onRecordingStopped?()
    }
}
