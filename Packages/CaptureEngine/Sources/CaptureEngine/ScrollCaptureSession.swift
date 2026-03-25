import AppKit
import ScreenCaptureKit
import OSLog
import Observation
import SharedModels
import Utilities

/// スクロールキャプチャセッション
/// エリア選択 → 自動スクロール → フレームキャプチャ → スティッチング
@Observable
@MainActor
public final class ScrollCaptureSession {
    /// キャプチャ済みフレーム
    public private(set) var frames: [CGImage] = []

    /// キャプチャ中かどうか
    public private(set) var isCapturing = false

    /// キャプチャ完了コールバック
    public var onComplete: ((CGImage) -> Void)?

    private let captureService: ScreenCaptureServiceProtocol
    private var captureRect: CGRect?
    private var display: SCDisplay?

    public init(captureService: ScreenCaptureServiceProtocol = ScreenCaptureService()) {
        self.captureService = captureService
    }

    /// スクロールキャプチャを開始
    public func start() async {
        guard !isCapturing else { return }

        // エリア選択
        guard let selectedRect = await AreaSelectionOverlay.selectArea() else {
            Logger.capture.info("スクロールキャプチャ: エリア選択がキャンセルされました")
            return
        }

        captureRect = selectedRect
        isCapturing = true
        frames.removeAll()

        do {
            let content = try await captureService.availableContent()
            guard let disp = content.displays.first else {
                Logger.capture.error("ディスプレイが見つかりません")
                isCapturing = false
                return
            }
            display = disp

            // 初回フレームをキャプチャ
            nonisolated(unsafe) let unsafeDisp = disp
            let firstFrame = try await captureService.captureArea(rect: selectedRect, display: unsafeDisp)
            frames.append(firstFrame)

            Logger.capture.info("スクロールキャプチャ開始: 初回フレーム取得")
        } catch {
            Logger.capture.error("スクロールキャプチャ初回フレーム失敗: \(error)")
            isCapturing = false
        }
    }

    /// 追加フレームをキャプチャ（スクロール後に呼び出す）
    public func captureFrame() async {
        guard isCapturing, let rect = captureRect, let disp = display else { return }

        do {
            nonisolated(unsafe) let unsafeDisp = disp
            let frame = try await captureService.captureArea(rect: rect, display: unsafeDisp)
            frames.append(frame)
            Logger.capture.info("スクロールキャプチャ: フレーム \(self.frames.count) 取得")
        } catch {
            Logger.capture.error("スクロールキャプチャフレーム失敗: \(error)")
        }
    }

    /// キャプチャを完了し、スティッチした画像を返す
    public func finish(overlap: Int = 20) -> CGImage? {
        isCapturing = false

        guard !frames.isEmpty else { return nil }

        let result = ImageStitcher.stitchVertically(images: frames, overlap: overlap)
        if let result {
            onComplete?(result)
            Logger.capture.info("スクロールキャプチャ完了: \(self.frames.count) フレーム → \(result.width)x\(result.height)")
        }

        frames.removeAll()
        captureRect = nil
        display = nil
        return result
    }

    /// キャプチャをキャンセル
    public func cancel() {
        isCapturing = false
        frames.removeAll()
        captureRect = nil
        display = nil
        Logger.capture.info("スクロールキャプチャがキャンセルされました")
    }
}
