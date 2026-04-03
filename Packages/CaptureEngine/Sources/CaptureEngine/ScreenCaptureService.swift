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
        // フルスクリーンキャプチャ → CGImage クロップ方式
        // sourceRect + width/height の組み合わせは SCStreamErrorDomain:-3 を引き起こすため回避
        let fullImage = try await captureDisplay(display: display, showsCursor: false)

        // ポイント座標 → ピクセル座標に変換してクロップ
        let scaleX = CGFloat(fullImage.width) / CGFloat(display.width)
        let scaleY = CGFloat(fullImage.height) / CGFloat(display.height)
        let pixelRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        guard let cropped = fullImage.cropping(to: pixelRect) else {
            Logger.capture.error("エリアクロップ失敗: rect=\(rect.debugDescription) pixelRect=\(pixelRect.debugDescription)")
            throw NSError(domain: "CaptureEngine", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "エリアのクロップに失敗しました"
            ])
        }

        Logger.capture.info("エリアキャプチャ完了: \(cropped.width)x\(cropped.height)")
        return cropped
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
        let image = try await captureDisplay(display: display, showsCursor: true)
        Logger.capture.info("フルスクリーンキャプチャ完了: \(display.width)x\(display.height)")
        return image
    }

    /// ディスプレイ全体をキャプチャする内部ヘルパー
    private func captureDisplay(display: SCDisplay, showsCursor: Bool) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()

        config.width = display.width
        config.height = display.height
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
