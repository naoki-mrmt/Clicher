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

    /// 録画開始コールバック（RecordingIndicator 表示用、録画範囲を含む）
    public var onRecordingStarted: ((_ screenRect: CGRect?) -> Void)?
    public var onRecordingStopped: (() -> Void)?

    /// 録画完了コールバック（動画ファイル URL）
    public var onRecordingComplete: ((URL) -> Void)?

    /// OCR 結果表示コールバック（テキストをパネルで表示）
    public var onOCRResult: ((String, CGImage) -> Void)?

    /// 録画中かどうか
    public private(set) var isRecording = false

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
            guard let self else { return }
            switch mode {
            case .area, .recording, .ocr:
                // エリア選択が必要なモード → 状態更新のみ（エリア選択は継続）
                modeBarSelectedMode = mode
            case .window, .fullscreen:
                // エリア選択不要なモード → overlay を閉じて即実行
                inlineAnnotate = nil
                overlay.dismiss()
                isCapturing = false
                startCapture(mode: mode)
            }
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

        // エリア選択と SCShareableContent 取得を並行実行（速度改善）
        async let selectionTask = AreaSelectionOverlay.select()
        async let contentTask: SCShareableContent? = try? captureService.availableContent()

        let selectionResult = await selectionTask
        let prefetchedContent = await contentTask

        guard let selectionResult else {
            // ESC キャンセル
            overlay.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            return
        }

        switch selectionResult {
        case .windowClick(let clickPoint):
            // クリック → ウィンドウキャプチャ
            overlay.dismiss()
            inlineAnnotate = nil
            await captureWindowAtPoint(clickPoint, prefetchedContent: prefetchedContent)

        case .area(let macRect):
            // ドラッグ → モードに応じて分岐
            let mode = modeBarSelectedMode

            switch mode {
            case .area:
                await captureAreaAfterSelection(macRect: macRect, overlay: overlay, prefetchedContent: prefetchedContent)
            case .recording:
                await startRecordingAfterSelection(macRect: macRect, overlay: overlay)
            case .ocr:
                overlay.dismiss()
                inlineAnnotate = nil
                await startOCRAfterSelection(macRect: macRect, prefetchedContent: prefetchedContent)
            default:
                overlay.dismiss()
                inlineAnnotate = nil
                isCapturing = false
            }
        }
    }

    // MARK: - Area Capture (after mode bar selection)

    /// モードタブ経由でエリア選択済みの場合のキャプチャ処理
    private func captureAreaAfterSelection(macRect: CGRect, overlay: InlineAnnotateOverlay, prefetchedContent: SCShareableContent? = nil) async {
        do {
            let content: SCShareableContent
            if let prefetchedContent {
                content = prefetchedContent
            } else {
                content = try await captureService.availableContent()
            }
            guard let display = findDisplay(for: macRect, in: content) else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }

            // キャプチャ前にオーバーレイを非表示
            overlay.hideModeTab()
            overlay.hideDim()
            try await Task.sleep(for: .milliseconds(16))

            nonisolated(unsafe) let unsafeDisplay = display
            let image = try await captureService.captureArea(macRect: macRect, display: unsafeDisplay)

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
    private func startOCRAfterSelection(macRect: CGRect, prefetchedContent: SCShareableContent? = nil) async {
        // オーバーレイ非表示がウィンドウサーバーに反映されるのを待つ
        try? await Task.sleep(for: .milliseconds(16))

        do {
            let content: SCShareableContent
            if let prefetchedContent {
                content = prefetchedContent
            } else {
                content = try await captureService.availableContent()
            }
            guard let display = findDisplay(for: macRect, in: content) else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }

            nonisolated(unsafe) let unsafeDisplay = display
            let image = try await captureService.captureArea(macRect: macRect, display: unsafeDisplay)

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
                // OCR 結果パネルを表示（ユーザーが確認してからコピー）
                onOCRResult?(fullText, image)
            }

            let result = CaptureResult(image: image, mode: .ocr, captureRect: macRect, ocrText: ocrResult.text)
            lastResult = result
        } catch {
            Logger.capture.error("OCR 失敗: \(error)")
            onError?("OCR 失敗: \(error.localizedDescription)")
        }
        isCapturing = false
    }

    /// モードタブ経由でエリア選択済みの場合の録画処理
    private func startRecordingAfterSelection(macRect: CGRect, overlay: InlineAnnotateOverlay) async {
        // macOS グローバル座標 → ディスプレイローカル SCK 座標に変換
        let screen = ScreenUtilities.screen(containing: macRect)
        let screenFrame = screen.frame
        let localX = macRect.origin.x - screenFrame.origin.x
        let localY = macRect.origin.y - screenFrame.origin.y
        let sckRect = CGRect(
            x: localX,
            y: screenFrame.height - localY - macRect.height,
            width: macRect.width,
            height: macRect.height
        )

        var audioSettings = RecordingAudioSettings()
        var didStart = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            overlay.showRecordingReady(
                screenRect: macRect,
                onStart: { settings in
                    audioSettings = settings
                    didStart = true
                    continuation.resume()
                },
                onCancel: { [weak self] in
                    overlay.dismiss()
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
        session.capturesSystemAudio = audioSettings.capturesSystemAudio
        session.capturesMicrophone = audioSettings.capturesMicrophone
        session.onComplete = { [weak self] url in
            guard let self else { return }
            Logger.capture.info("録画ファイル: \(url.path)")
            isRecording = false
            isCapturing = false
            onRecordingStopped?()
            onRecordingComplete?(url)
        }
        session.onError = { [weak self] message in
            self?.onError?(message)
        }
        recordingSession = session

        // エリアを含むディスプレイを特定
        let targetDisplay: SCDisplay?
        if let content = try? await captureService.availableContent() {
            let displayID = ScreenUtilities.displayID(for: screen)
            targetDisplay = content.displays.first { $0.displayID == displayID }
        } else {
            targetDisplay = nil
        }

        do {
            try await session.start(display: targetDisplay, sourceRect: sckRect)
            onRecordingStarted?(macRect)
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
        async let selectionTask = AreaSelectionOverlay.select()
        async let contentTask = captureService.availableContent()

        let selectionResult = await selectionTask

        // ウィンドウクリックの場合
        if case .windowClick(let clickPoint) = selectionResult {
            let prefetchedContent = try? await contentTask
            inlineAnnotate?.dismiss()
            inlineAnnotate = nil
            await captureWindowAtPoint(clickPoint, prefetchedContent: prefetchedContent)
            return
        }

        guard case .area(let macRect) = selectionResult else {
            Logger.capture.info("エリア選択がキャンセルされました")
            _ = try? await contentTask
            inlineAnnotate?.dismiss()
            inlineAnnotate = nil
            isCapturing = false
            return
        }

        do {
            let content = try await contentTask
            guard let display = findDisplay(for: macRect, in: content) else {
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

    /// クリック位置のウィンドウをキャプチャし、インラインアノテーションを表示
    private func captureWindowAtPoint(_ clickPoint: CGPoint, prefetchedContent: SCShareableContent? = nil) async {
        do {
            let content: SCShareableContent
            if let prefetchedContent {
                content = prefetchedContent
            } else {
                content = try await captureService.availableContent()
            }

            let bundleID = Bundle.main.bundleIdentifier
            let screenHeight = ScreenUtilities.activeScreenFrame.height
            // macOS 座標（左下原点）→ SCK 座標（左上原点）
            let flippedY = screenHeight - clickPoint.y

            // クリック位置を含むウィンドウを検索（最前面から順に）
            let validWindows = content.windows.filter { window in
                window.isOnScreen
                    && window.frame.width > 10
                    && window.frame.height > 10
                    && window.owningApplication?.bundleIdentifier != bundleID
            }

            guard let targetWindow = validWindows.first(where: { window in
                window.frame.contains(CGPoint(x: clickPoint.x, y: flippedY))
            }) else {
                Logger.capture.info("クリック位置にウィンドウが見つかりません")
                isCapturing = false
                return
            }

            nonisolated(unsafe) let unsafeWindow = targetWindow
            let image = try await captureService.captureWindow(unsafeWindow)

            // SCK 座標（左上原点）→ macOS 座標（左下原点）に変換
            let windowFrame = targetWindow.frame
            let macRect = CGRect(
                x: windowFrame.origin.x,
                y: screenHeight - windowFrame.origin.y - windowFrame.height,
                width: windowFrame.width,
                height: windowFrame.height
            )

            // インラインアノテーションを表示（エリア選択後と同じ編集UI）
            let overlay = InlineAnnotateOverlay()
            overlay.onComplete = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .window, captureRect: macRect)
                lastResult = result
                onCaptureComplete?(result)
                inlineAnnotate = nil
                isCapturing = false
            }
            overlay.onSave = { [weak self] editedImage in
                guard let self else { return }
                let result = CaptureResult(image: editedImage, mode: .window, captureRect: macRect)
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
            Logger.capture.error("ウィンドウキャプチャ失敗: \(error)")
            onError?("ウィンドウキャプチャ失敗: \(error.localizedDescription)")
            isCapturing = false
        }
    }

    // MARK: - Fullscreen Capture

    private func startFullscreenCapture() async {
        isCapturing = true
        defer { isCapturing = false }

        do {
            let content = try await captureService.availableContent()
            guard let display = findActiveDisplay(in: content) else {
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
            guard let display = findDisplay(for: macRect, in: content) else {
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
                onOCRResult?(fullText, image)
            }

            let result = CaptureResult(
                image: image, mode: .ocr, captureRect: macRect,
                ocrText: ocrResult.text.isEmpty ? nil : ocrResult.text
            )
            lastResult = result
        } catch {
            Logger.capture.error("OCR キャプチャ失敗: \(error)")
            onError?("OCR キャプチャ失敗: \(error.localizedDescription)")
        }
    }

    /// 録画を停止
    public func stopRecording() async {
        await recordingSession?.stop()
        // onRecordingStopped は session.onComplete 経由で発火済み
        recordingSession = nil
    }

    // MARK: - Display Utilities

    /// macOS 座標の矩形を含むディスプレイを返す（マルチディスプレイ対応）
    /// nonisolated(unsafe) でラップ済み（SCDisplay は non-Sendable のため）
    private nonisolated func findDisplay(for macRect: CGRect, in content: SCShareableContent) -> SCDisplay? {
        nonisolated(unsafe) let displays = content.displays
        let targetDisplayID = ScreenUtilities.displayID(for: ScreenUtilities.screen(containing: macRect))
        return displays.first { $0.displayID == targetDisplayID }
            ?? displays.first
    }

    /// マウスカーソル位置のディスプレイを返す
    private nonisolated func findActiveDisplay(in content: SCShareableContent) -> SCDisplay? {
        nonisolated(unsafe) let displays = content.displays
        let targetDisplayID = ScreenUtilities.displayID(for: ScreenUtilities.activeScreen)
        return displays.first { $0.displayID == targetDisplayID }
            ?? displays.first
    }
}
