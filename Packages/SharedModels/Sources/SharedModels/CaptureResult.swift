import AppKit

/// キャプチャの結果を保持する型
public struct CaptureResult: @unchecked Sendable {
    /// キャプチャされた画像
    public let image: CGImage

    /// キャプチャに使用したモード
    public let mode: CaptureMode

    /// キャプチャ範囲（画面座標系）
    public let captureRect: CGRect

    /// キャプチャ時刻
    public let timestamp: Date

    /// OCR で認識されたテキスト（OCR モード時のみ）
    public let ocrText: String?

    /// NSImage に変換
    public var nsImage: NSImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    public init(image: CGImage, mode: CaptureMode, captureRect: CGRect = .zero, ocrText: String? = nil) {
        self.image = image
        self.mode = mode
        self.captureRect = captureRect
        self.timestamp = Date()
        self.ocrText = ocrText
    }
}
