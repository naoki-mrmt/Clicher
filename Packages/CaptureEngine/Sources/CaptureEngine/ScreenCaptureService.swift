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

        let imgW = CGFloat(fullImage.width)
        let imgH = CGFloat(fullImage.height)

        // rect は NSScreen 座標空間（ディスプレイスケーリング適用済み）で渡される
        // NSScreen.frame と display.width/height が異なる場合（「スペースを拡大」等）に対応するため
        // NSScreen のサイズを基準にピクセル変換する
        let displayW = CGFloat(display.width)
        let displayH = CGFloat(display.height)
        let screenSize = await MainActor.run {
            NSScreen.main?.frame.size ?? CGSize(width: displayW, height: displayH)
        }

        let toPixelX = imgW / screenSize.width
        let toPixelY = imgH / screenSize.height

        Logger.capture.info("エリアクロップ: rect=\(rect.debugDescription) image=\(fullImage.width)x\(fullImage.height) screen=\(screenSize.debugDescription) display=\(display.width)x\(display.height) toPixel=\(toPixelX)x\(toPixelY)")

        // NSScreen 座標 → ピクセル座標に変換し、整数に丸めて画像境界にクランプ
        let rawRect = CGRect(
            x: rect.origin.x * toPixelX,
            y: rect.origin.y * toPixelY,
            width: rect.width * toPixelX,
            height: rect.height * toPixelY
        )
        let imageBounds = CGRect(x: 0, y: 0, width: imgW, height: imgH)
        let pixelRect = rawRect.integral.intersection(imageBounds)

        guard !pixelRect.isNull, pixelRect.width > 0, pixelRect.height > 0,
              let cropped = fullImage.cropping(to: pixelRect) else {
            Logger.capture.error("エリアクロップ失敗: rawRect=\(rawRect.debugDescription) pixelRect=\(pixelRect.debugDescription) imageBounds=\(imageBounds.debugDescription)")
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

        // Retina 対応: ピクセル単位で出力サイズを指定
        let scaleFactor = await MainActor.run {
            NSScreen.main?.backingScaleFactor ?? 2.0
        }
        config.width = Int(CGFloat(display.width) * scaleFactor)
        config.height = Int(CGFloat(display.height) * scaleFactor)
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
