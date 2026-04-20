import AppKit
import ScreenCaptureKit
import CoreGraphics
import OSLog
import Observation
import Utilities

/// Lark 風スクロールキャプチャセッション
/// エリア選択後、スクロールイベントを監視してフレームを自動キャプチャし、最後にスティッチ
@Observable
@MainActor
public final class ScrollCaptureSession {
    /// キャプチャ済みフレーム数
    public private(set) var frameCount = 0

    /// キャプチャ中かどうか
    public private(set) var isCapturing = false

    /// 自動スクロール中かどうか
    public private(set) var isAutoScrolling = false

    private let captureService: ScreenCaptureServiceProtocol
    private var macRect: CGRect = .zero
    private var display: SCDisplay?
    private var frames: [CGImage] = []
    private var scrollMonitor: Any?
    private var autoScrollTask: Task<Void, Never>?

    /// スクロールのデルタ蓄積（閾値に達したらフレーム取得）
    private var accumulatedScrollDelta: CGFloat = 0
    /// フレーム取得のスクロール閾値（ピクセル）
    private let scrollThreshold: CGFloat = 60

    /// 完了コールバック（スティッチ済み画像）
    public var onComplete: ((CGImage) -> Void)?
    /// フレーム取得時のコールバック
    public var onFrameCaptured: ((Int) -> Void)?
    /// エラーコールバック
    public var onError: ((String) -> Void)?

    public init(captureService: ScreenCaptureServiceProtocol = ScreenCaptureService()) {
        self.captureService = captureService
    }

    /// スクロールキャプチャを開始
    /// - Parameters:
    ///   - macRect: キャプチャ範囲（macOS スクリーン座標）
    ///   - content: SCShareableContent（事前取得済みの場合）
    public func start(macRect: CGRect, content: SCShareableContent? = nil) async {
        guard !isCapturing else { return }

        isCapturing = true
        frames.removeAll()
        frameCount = 0
        self.macRect = macRect

        do {
            let availableContent: SCShareableContent
            if let content {
                availableContent = content
            } else {
                availableContent = try await captureService.availableContent()
            }
            let screen = ScreenUtilities.screen(containing: macRect)
            let targetDisplayID = ScreenUtilities.displayID(for: screen)
            guard let disp = availableContent.displays.first(where: { $0.displayID == targetDisplayID })
                    ?? availableContent.displays.first else {
                Logger.capture.error("スクロールキャプチャ: ディスプレイが見つかりません")
                isCapturing = false
                return
            }
            self.display = disp

            // 初回フレーム取得
            await captureFrame()

            // スクロールイベントの監視を開始
            startScrollMonitoring()

            Logger.capture.info("スクロールキャプチャ開始: \(macRect.debugDescription)")
        } catch {
            Logger.capture.error("スクロールキャプチャ開始失敗: \(error)")
            onError?(error.localizedDescription)
            isCapturing = false
        }
    }

    /// 自動スクロールを開始
    public func startAutoScroll() {
        guard isCapturing, !isAutoScrolling else { return }
        isAutoScrolling = true

        autoScrollTask = Task { [weak self] in
            // 専用 EventSource でユーザー入力と干渉しないようにする
            let source = CGEventSource(stateID: .combinedSessionState)

            while !Task.isCancelled {
                guard let self, self.isCapturing, self.isAutoScrolling else { break }

                // キャプチャエリアの中心にスクロールイベントを送信
                let centerX = self.macRect.midX
                let mainHeight = NSScreen.screens.first?.frame.height ?? 0
                let centerY = mainHeight - self.macRect.midY // CG座標に変換
                let location = CGPoint(x: centerX, y: centerY)

                if let scrollEvent = CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: -3, wheel2: 0, wheel3: 0) {
                    scrollEvent.location = location
                    scrollEvent.post(tap: .cghidEventTap)
                }

                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    /// 自動スクロールを停止
    public func stopAutoScroll() {
        isAutoScrolling = false
        autoScrollTask?.cancel()
        autoScrollTask = nil
    }

    /// キャプチャを完了し、スティッチ結果を返す
    public func finish() {
        guard isCapturing else { return }
        stopAutoScroll()
        stopScrollMonitoring()
        isCapturing = false

        guard frames.count > 1 else {
            if let single = frames.first {
                onComplete?(single)
            }
            cleanup()
            return
        }

        // スティッチ処理
        if let result = ImageStitcher.stitchVertically(images: frames) {
            onComplete?(result)
            Logger.capture.info("スクロールキャプチャ完了: \(self.frames.count) フレーム")
        } else {
            onError?("画像の結合に失敗しました")
        }
        cleanup()
    }

    /// キャプチャをキャンセル
    public func cancel() {
        stopAutoScroll()
        stopScrollMonitoring()
        isCapturing = false
        cleanup()
        Logger.capture.info("スクロールキャプチャがキャンセルされました")
    }

    // MARK: - Frame Capture

    /// フレームを1枚取得
    private func captureFrame() async {
        guard isCapturing, let disp = display else { return }

        do {
            nonisolated(unsafe) let unsafeDisp = disp
            let image = try await captureService.captureArea(macRect: macRect, display: unsafeDisp)
            frames.append(image)
            frameCount = frames.count
            onFrameCaptured?(frameCount)
        } catch {
            Logger.capture.error("スクロールキャプチャフレーム失敗: \(error)")
        }
    }

    // MARK: - Scroll Monitoring

    private func startScrollMonitoring() {
        accumulatedScrollDelta = 0

        // グローバルスクロールイベントを監視
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.isCapturing else { return }
                // 縦スクロールのデルタを蓄積
                self.accumulatedScrollDelta += abs(event.scrollingDeltaY)

                if self.accumulatedScrollDelta >= self.scrollThreshold {
                    self.accumulatedScrollDelta = 0
                    await self.captureFrame()
                }
            }
        }
    }

    private func stopScrollMonitoring() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    private func cleanup() {
        frames.removeAll()
        frameCount = 0
        display = nil
        macRect = .zero
    }
}
