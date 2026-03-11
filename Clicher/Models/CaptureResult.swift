import AppKit
import CoreGraphics

/// キャプチャ結果を保持する型
struct CaptureResult: Identifiable, Sendable {
    let id = UUID()
    let image: CGImage
    let captureMode: CaptureMode
    let capturedAt: Date
    let sourceRect: CGRect

    /// NSImage への変換
    var nsImage: NSImage {
        NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }

    /// クリップボードにコピー
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
    }

    /// ファイルに保存
    func save(to url: URL, format: ExportFormat = .png) throws {
        let data: Data?
        switch format {
        case .png:
            data = nsImage.tiffRepresentation.flatMap {
                NSBitmapImageRep(data: $0)?.representation(using: .png, properties: [:])
            }
        case .jpeg(let quality):
            data = nsImage.tiffRepresentation.flatMap {
                NSBitmapImageRep(data: $0)?.representation(
                    using: .jpeg,
                    properties: [.compressionFactor: quality]
                )
            }
        }
        guard let imageData = data else {
            throw CaptureError.exportFailed
        }
        try imageData.write(to: url)
    }
}

/// エクスポート形式
enum ExportFormat: Sendable {
    case png
    case jpeg(quality: Double)

    var isPng: Bool {
        if case .png = self { return true }
        return false
    }

    var fileExtension: String {
        switch self {
        case .png: "png"
        case .jpeg: "jpg"
        }
    }
}

/// キャプチャ関連エラー
enum CaptureError: LocalizedError, Sendable {
    case permissionDenied
    case captureFailedGeneric
    case noWindowSelected
    case noDisplayFound
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied: "Screen recording permission is required."
        case .captureFailedGeneric: "Failed to capture the screen."
        case .noWindowSelected: "No window was selected."
        case .noDisplayFound: "No display found."
        case .exportFailed: "Failed to export the image."
        }
    }
}
