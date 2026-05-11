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

    /// スティッチ処理中かどうか（完了押下後の重い処理ガード用）
    public private(set) var isStitching = false

    private let captureService: ScreenCaptureServiceProtocol
    private var macRect: CGRect = .zero
    private var display: SCDisplay?
    private var frames: [CGImage] = []
    private var scrollMonitor: Any?
    private var autoScrollTask: Task<Void, Never>?

    /// 手動スクロールのデルタ蓄積（閾値に達したらフレーム取得）
    private var accumulatedScrollDelta: CGFloat = 0
    /// フレーム取得のスクロール閾値（ピクセル）
    private let scrollThreshold: CGFloat = 60

    /// 自動スクロール 1 イベントあたりのピクセル数
    private let autoScrollPixelsPerEvent: Int32 = 10
    /// 自動スクロールイベント間隔（ms）
    private let autoScrollIntervalMs: Int = 50

    /// 直近フレームの軽量ハッシュ（終端検出用）
    private var lastFrameSignature: [UInt8] = []
    /// 連続して直近フレームと近似一致したカウント
    private var identicalFrameStreak = 0
    /// 連続一致でスクロール終端とみなす回数
    private let endOfContentThreshold = 2
    /// 取得可能な最大フレーム数（メモリ保護）
    private let maxFrameCount = 200

    /// 完了コールバック（スティッチ済み画像）
    public var onComplete: ((CGImage) -> Void)?
    /// フレーム取得時のコールバック
    public var onFrameCaptured: ((Int) -> Void)?
    /// エラーコールバック
    public var onError: ((String) -> Void)?
    /// 自動スクロール停止コールバック（終端検出・上限到達等で内部停止した場合に UI を同期するため）
    public var onAutoScrollStopped: (() -> Void)?
    /// スティッチ開始/終了コールバック（UI のローディング表示用）
    public var onStitchingStart: (() -> Void)?
    public var onStitchingEnd: (() -> Void)?

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
        lastFrameSignature = []
        identicalFrameStreak = 0
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
                onError?("スクロールキャプチャ: 対象ディスプレイが見つかりません")
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

        // Accessibility 権限が無いと CGEvent.post は無音失敗するので事前チェック
        guard AXIsProcessTrusted() else {
            Logger.capture.error("自動スクロール: Accessibility 権限がありません")
            onError?("自動スクロールには『アクセシビリティ』権限が必要です。システム設定 > プライバシーとセキュリティ > アクセシビリティ で Clicher を許可してください。")
            // View 側が楽観的に Stop 表示に切り替えているため、UI を元に戻すよう通知
            onAutoScrollStopped?()
            return
        }

        isAutoScrolling = true

        let pixelsPerEvent = autoScrollPixelsPerEvent
        let intervalMs = autoScrollIntervalMs
        let threshold = scrollThreshold

        autoScrollTask = Task { [weak self] in
            // 専用 EventSource でユーザー入力と干渉しないようにする
            let source = CGEventSource(stateID: .combinedSessionState)
            var pixelsSinceLastFrame: CGFloat = 0

            while !Task.isCancelled {
                guard let self, self.isCapturing, self.isAutoScrolling else { break }

                // キャプチャエリアの中心にスクロールイベントを送信
                // .cgSessionEventTap を使うことで HID レベルでのカーソルワープを回避
                // （HID で post すると event.location 指定がカーソルを動かしてしまう）
                let centerX = self.macRect.midX
                let mainHeight = NSScreen.screens.first?.frame.height ?? 0
                let centerY = mainHeight - self.macRect.midY // CG座標に変換
                let location = CGPoint(x: centerX, y: centerY)

                if let scrollEvent = CGEvent(
                    scrollWheelEvent2Source: source,
                    units: .pixel,
                    wheelCount: 1,
                    wheel1: -pixelsPerEvent,
                    wheel2: 0,
                    wheel3: 0
                ) {
                    scrollEvent.location = location
                    scrollEvent.post(tap: .cgSessionEventTap)
                }

                // .cgSessionEventTap だと NSEvent.addGlobalMonitorForEvents が拾わない可能性が
                // あるため、自動スクロール中はループ内で手動にフレーム取得する
                pixelsSinceLastFrame += CGFloat(pixelsPerEvent)
                if pixelsSinceLastFrame >= threshold {
                    pixelsSinceLastFrame = 0
                    await self.captureFrame()
                    // captureFrame 後にループ条件を再確認（終端検出で停止しているかも）
                    guard self.isCapturing, self.isAutoScrolling else { break }
                }

                try? await Task.sleep(for: .milliseconds(intervalMs))
            }
        }
    }

    /// 自動スクロールを停止
    public func stopAutoScroll() {
        guard isAutoScrolling else { return }
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

        guard !frames.isEmpty else {
            onError?("スクロールキャプチャ: フレームを 1 枚も取得できませんでした")
            cleanup()
            return
        }

        guard frames.count > 1 else {
            if let single = frames.first {
                onComplete?(single)
            }
            cleanup()
            return
        }

        // フレームを取り出してから cleanup（参照を残してから async 処理に渡すため）
        let framesToStitch = frames
        frames.removeAll()
        isStitching = true
        onStitchingStart?()

        // スティッチは数百ms〜数秒かかりうるので detached でバックグラウンド処理
        Task.detached(priority: .userInitiated) { [weak self] in
            let result = ImageStitcher.stitchVertically(images: framesToStitch)

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.isStitching = false
                self.onStitchingEnd?()
                if let result {
                    self.onComplete?(result)
                    Logger.capture.info("スクロールキャプチャ完了: \(framesToStitch.count) フレーム")
                } else {
                    self.onError?("画像の結合に失敗しました")
                }
                self.cleanup()
            }
        }
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

            // 終端検出: 直近フレームと近似一致したらスキップ + カウント
            let signature = sampleSignature(of: image)
            if isNearlyIdentical(signature, lastFrameSignature) {
                identicalFrameStreak += 1
                if identicalFrameStreak >= endOfContentThreshold && isAutoScrolling {
                    Logger.capture.info("スクロール終端を検出: 自動スクロールを停止")
                    stopAutoScroll()
                    onAutoScrollStopped?()
                }
                return
            }
            identicalFrameStreak = 0
            lastFrameSignature = signature

            frames.append(image)
            frameCount = frames.count
            onFrameCaptured?(frameCount)

            // フレーム上限到達: 自動スクロールを停止してユーザに完了を促す
            if frames.count >= maxFrameCount && isAutoScrolling {
                Logger.capture.info("フレーム上限(\(self.maxFrameCount))到達: 自動スクロールを停止")
                stopAutoScroll()
                onAutoScrollStopped?()
                onError?("フレーム数が上限(\(maxFrameCount))に達しました。完了ボタンで結合してください。")
            }
        } catch {
            Logger.capture.error("スクロールキャプチャフレーム失敗: \(error)")
            onError?("フレーム取得失敗: \(error.localizedDescription)")
        }
    }

    // MARK: - End-of-Content Detection

    /// フレームから軽量シグネチャを取得（中央行から ~50 サンプル）
    /// 完全比較は重いので、行サンプルで十分実用的
    private func sampleSignature(of image: CGImage) -> [UInt8] {
        guard let data = image.dataProvider?.data as Data? else { return [] }
        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = max(1, image.bitsPerPixel / 8)
        let rowsToSample = [image.height / 4, image.height / 2, image.height * 3 / 4]
        let samplesPerRow = 50
        let step = max(1, image.width / samplesPerRow)

        var signature: [UInt8] = []
        signature.reserveCapacity(rowsToSample.count * samplesPerRow * 3)

        for row in rowsToSample {
            guard row < image.height else { continue }
            let rowStart = row * bytesPerRow
            for x in stride(from: 0, to: image.width, by: step) {
                let idx = rowStart + x * bytesPerPixel
                guard idx + 2 < data.count else { break }
                signature.append(data[idx])
                signature.append(data[idx + 1])
                signature.append(data[idx + 2])
            }
        }
        return signature
    }

    /// 2 つのシグネチャがほぼ同じか判定（95% 以上のピクセルが ±8 以内で一致）
    private func isNearlyIdentical(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        guard !a.isEmpty, a.count == b.count else { return false }
        var matchCount = 0
        for i in 0..<a.count where abs(Int(a[i]) - Int(b[i])) < 8 {
            matchCount += 1
        }
        return Double(matchCount) / Double(a.count) > 0.95
    }

    // MARK: - Scroll Monitoring

    private func startScrollMonitoring() {
        accumulatedScrollDelta = 0

        // グローバルスクロールイベントを監視（手動スクロール用）
        // 自動スクロール中はループ側でフレーム取得するため、ここではスキップ
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self else { return }
            let deltaY = abs(event.scrollingDeltaY)
            Task { @MainActor in
                guard self.isCapturing, !self.isAutoScrolling else { return }
                self.accumulatedScrollDelta += deltaY

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
        lastFrameSignature = []
        identicalFrameStreak = 0
        accumulatedScrollDelta = 0
    }
}
