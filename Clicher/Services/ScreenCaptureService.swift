import ScreenCaptureKit
import CoreGraphics
import AppKit

/// ScreenCaptureKit を使用したキャプチャサービス
protocol ScreenCaptureServiceProtocol: Sendable {
    func captureArea(rect: CGRect, display: SCDisplay) async throws -> CGImage
    func captureWindow(_ window: SCWindow) async throws -> CGImage
    func captureFullscreen(display: SCDisplay) async throws -> CGImage
    func availableContent() async throws -> SCShareableContent
}

/// ScreenCaptureKit ラッパー
final class ScreenCaptureService: ScreenCaptureServiceProtocol {
    nonisolated func captureArea(rect: CGRect, display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.sourceRect = rect
        config.width = Int(rect.width * 2) // Retina
        config.height = Int(rect.height * 2)
        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureSampleBuffer(
            contentFilter: filter,
            configuration: config
        )
        guard let cgImage = imageFromSampleBuffer(image) else {
            throw CaptureError.captureFailedGeneric
        }
        return cgImage
    }

    nonisolated func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.captureResolution = .best
        config.ignoreShadow = false

        if let frame = window.frame as CGRect? {
            config.width = Int(frame.width * 2)
            config.height = Int(frame.height * 2)
        }

        let image = try await SCScreenshotManager.captureSampleBuffer(
            contentFilter: filter,
            configuration: config
        )
        guard let cgImage = imageFromSampleBuffer(image) else {
            throw CaptureError.captureFailedGeneric
        }
        return cgImage
    }

    nonisolated func captureFullscreen(display: SCDisplay) async throws -> CGImage {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.showsCursor = false
        config.captureResolution = .best

        let image = try await SCScreenshotManager.captureSampleBuffer(
            contentFilter: filter,
            configuration: config
        )
        guard let cgImage = imageFromSampleBuffer(image) else {
            throw CaptureError.captureFailedGeneric
        }
        return cgImage
    }

    nonisolated func availableContent() async throws -> SCShareableContent {
        try await SCShareableContent.current
    }

    // MARK: - Private

    private nonisolated func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = sampleBuffer.imageBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
