import ScreenCaptureKit
import CoreGraphics
import OSLog
import Utilities

/// ScreenCaptureKit を使ったキャプチャサービス
/// Protocol で抽象化し、テスト時にモック可能にする
public protocol ScreenCaptureServiceProtocol: Sendable {
    /// エリアキャプチャ（macOS スクリーン座標・左下原点）
    func captureArea(macRect: CGRect, display: SCDisplay) async throws -> CGImage

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

    public func captureArea(macRect: CGRect, display: SCDisplay) async throws -> CGImage {
        // macOS スクリーン座標（左下原点）→ CG ディスプレイ座標（左上原点）
        // マルチディスプレイ対応: macRect を含むスクリーンの displayID を使用
        let screen = ScreenUtilities.screen(containing: macRect)
        let displayID = ScreenUtilities.displayID(for: screen)
        let displayBounds = CGDisplayBounds(displayID)
        let cgRect = CGRect(
            x: macRect.origin.x,
            y: displayBounds.height - macRect.origin.y - macRect.height,
            width: macRect.width,
            height: macRect.height
        )

        Logger.capture.info("エリアキャプチャ: macRect=\(macRect.debugDescription) cgRect=\(cgRect.debugDescription)")

        // SCScreenshotManager の sourceRect にバグがあるため CGWindowListCreateImage を使用
        guard let image = CGWindowListCreateImage(
            cgRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            .bestResolution
        ) else {
            Logger.capture.error("エリアキャプチャ失敗: cgRect=\(cgRect.debugDescription)")
            throw NSError(domain: "CaptureEngine", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "エリアキャプチャに失敗しました"
            ])
        }

        Logger.capture.info("エリアキャプチャ完了: \(image.width)x\(image.height)")
        return image
    }

    public func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()

        // Retina 対応: ポイントサイズにスケールファクターを乗算
        let scaleFactor = ScreenUtilities.activeScaleFactor
        config.width = Int(window.frame.width * scaleFactor)
        config.height = Int(window.frame.height * scaleFactor)
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
        let image = try await captureDisplay(display: display, showsCursor: true)
        Logger.capture.info("フルスクリーンキャプチャ完了: \(display.width)x\(display.height)")
        return image
    }

    /// ディスプレイ全体をキャプチャする内部ヘルパー
    private func captureDisplay(display: SCDisplay, showsCursor: Bool) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        // Retina: 対象ディスプレイのネイティブピクセルモードで取得
        let displayID = display.displayID
        let pixelWidth = CGDisplayPixelsWide(displayID)
        let pixelHeight = CGDisplayPixelsHigh(displayID)
        config.width = pixelWidth
        config.height = pixelHeight
        config.showsCursor = showsCursor
        config.captureResolution = .best

        return try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: config
        )
    }

    public func availableContent() async throws -> SCShareableContent {
        try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    }
}
