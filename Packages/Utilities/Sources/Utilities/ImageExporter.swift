import AppKit
import UniformTypeIdentifiers
import OSLog
import SharedModels

/// 画像のエクスポート（保存・クリップボード）を管理
public enum ImageExporter {
    /// 画像をクリップボードにコピー
    @MainActor
    public static func copyToClipboard(_ image: CGImage) {
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([nsImage])
        Logger.capture.info("画像をクリップボードにコピーしました")
    }

    /// 画像をファイルに保存
    public static func saveToFile(
        _ image: CGImage,
        format: ImageFormat = .png,
        directory: URL? = nil
    ) -> URL? {
        guard image.width > 0, image.height > 0 else {
            Logger.capture.error("画像サイズが不正: \(image.width)x\(image.height)")
            return nil
        }
        let saveDir = directory ?? defaultSaveDirectory()
        let fileName = generateFileName(format: format)
        let fileURL = saveDir.appendingPathComponent(fileName)

        // 保存先ディレクトリが存在しなければ作成
        let fm = FileManager.default
        if !fm.fileExists(atPath: saveDir.path) {
            do {
                try fm.createDirectory(at: saveDir, withIntermediateDirectories: true)
            } catch {
                Logger.capture.error("保存先ディレクトリの作成に失敗: \(error)")
                return nil
            }
        }

        guard let destination = CGImageDestinationCreateWithURL(
            fileURL as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            Logger.capture.error("CGImageDestination の作成に失敗")
            return nil
        }

        var options: [CFString: Any] = [:]
        if format == .jpeg {
            options[kCGImageDestinationLossyCompressionQuality] = 0.9
        }

        CGImageDestinationAddImage(destination, image, options as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            Logger.capture.error("画像の保存に失敗: \(fileURL.path)")
            return nil
        }

        Logger.capture.info("画像を保存しました: \(fileURL.lastPathComponent)")
        return fileURL
    }

    /// NSSavePanel でユーザーに保存先を選択させる
    @MainActor
    public static func saveWithPanel(_ image: CGImage, format: ImageFormat = .png) async -> URL? {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.utType]
        panel.nameFieldStringValue = generateFileName(format: format)
        panel.canCreateDirectories = true

        let response = await panel.beginSheetModal(for: NSApp.keyWindow ?? NSWindow())
        guard response == .OK, let url = panel.url else {
            return nil
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            format.utType.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        Logger.capture.info("画像を保存しました: \(url.lastPathComponent)")
        return url
    }

    // MARK: - Helpers

    private static func defaultSaveDirectory() -> URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        return desktop ?? FileManager.default.temporaryDirectory
    }

    private static let fileNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return f
    }()

    public static func generateFileName(format: ImageFormat) -> String {
        let timestamp = fileNameFormatter.string(from: Date())
        return "Clicher_\(timestamp).\(format.fileExtension)"
    }
}
