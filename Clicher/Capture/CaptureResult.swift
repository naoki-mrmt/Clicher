import AppKit

/// キャプチャの結果を保持する型
struct CaptureResult: Sendable {
    /// キャプチャされた画像
    let image: CGImage

    /// キャプチャに使用したモード
    let mode: CaptureMode

    /// キャプチャ範囲（画面座標系）
    let captureRect: CGRect

    /// キャプチャ時刻
    let timestamp: Date

    /// NSImage に変換
    var nsImage: NSImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    init(image: CGImage, mode: CaptureMode, captureRect: CGRect = .zero) {
        self.image = image
        self.mode = mode
        self.captureRect = captureRect
        self.timestamp = Date()
    }
}
