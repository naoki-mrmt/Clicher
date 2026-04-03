import ScreenCaptureKit
import CoreGraphics
import OSLog
import Utilities

/// ScreenCaptureKit を使ったキャプチャサービス
/// Protocol で抽象化し、テスト時にモック可能にする
public protocol ScreenCaptureServiceProtocol: Sendable {
    /// エリアキャプチャ（指定範囲）
    func captureArea(rect: CGRect, display: SCDisplay) async throws -> CGImage

    /// ウィンドウキャプチャ
    func captureWindow(_ window: SCWindow) async throws -> CGImage

    /// フルスクリーンキャプチャ
    func captureFullscreen(display: SCDisplay) async throws -> CGImage

    /// 利用可能なディスプレイとウィンドウを取得
    func availableContent() async throws -> SCShareableContent
}

/// ScreenCaptureKit 実装
public final class ScreenCaptureService: ScreenCaptureServiceProtocol, Sendable {
    public init() {}

    public func captureArea(rect: CGRect, display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // sourceRect はポイント座標で指定
        // width/height もポイント単位で指定し、captureResolution = .best で Retina 解像度を自動取得
        config.sourceRect = rect
        config.width = Int(rect.width)
        config.height = Int(rect.height)
        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        Logger.capture.info("エリアキャプチャ完了: \(Int(rect.width))x\(Int(rect.height))")
        return image
    }

    public func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()

        // width/height はポイント単位で指定、captureResolution = .best が Retina を自動処理
        config.width = Int(window.frame.width)
        config.height = Int(window.frame.height)
        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        Logger.capture.info("ウィンドウキャプチャ完了: \(window.title ?? "無題")")
        return image
    }

    public func captureFullscreen(display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // width/height はポイント単位で指定、captureResolution = .best が Retina を自動処理
        config.width = display.width
        config.height = display.height
        config.showsCursor = true
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )

        Logger.capture.info("フルスクリーンキャプチャ完了: \(display.width)x\(display.height)")
        return image
    }

    public func availableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
}
