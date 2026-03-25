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

        // Retina 対応: バッキングスケールファクターを考慮
        let scaleFactor = await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }

        config.sourceRect = rect
        config.width = Int(rect.width * scaleFactor)
        config.height = Int(rect.height * scaleFactor)
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

        let scaleFactor = await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }

        config.width = Int(CGFloat(window.frame.width) * scaleFactor)
        config.height = Int(CGFloat(window.frame.height) * scaleFactor)
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

        let scaleFactor = await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }

        config.width = display.width * Int(scaleFactor)
        config.height = display.height * Int(scaleFactor)
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
