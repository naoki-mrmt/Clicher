import Foundation
import CoreGraphics
import AppKit
import OSLog
import SharedModels

/// キャプチャ履歴エントリ
public struct CaptureHistoryEntry: Codable, Identifiable, Sendable {
    public let id: UUID
    public let mode: String
    public let timestamp: Date
    public let width: Int
    public let height: Int
    public let filePath: String?
    public let thumbnailPath: String

    public init(
        id: UUID = UUID(),
        mode: CaptureMode,
        timestamp: Date = Date(),
        width: Int,
        height: Int,
        filePath: String? = nil,
        thumbnailPath: String
    ) {
        self.id = id
        self.mode = mode.label
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.filePath = filePath
        self.thumbnailPath = thumbnailPath
    }

    /// 日付のフォーマット済み文字列
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    public var formattedDate: String {
        Self.dateFormatter.string(from: timestamp)
    }

    /// サイズの表示文字列
    public var sizeLabel: String {
        "\(width) × \(height)"
    }
}

/// キャプチャ履歴の永続化ストレージ
/// ~/Library/Application Support/Clicher/history/ に保存
@MainActor
public final class CaptureHistoryStore {
    private let historyDirectory: URL
    private let thumbnailDirectory: URL
    private let indexURL: URL
    private var entries: [CaptureHistoryEntry] = []

    /// 最大履歴数
    public let maxEntries: Int

    /// エラー通知コールバック
    public var onError: ((String) -> Void)?

    public init(maxEntries: Int = 100) {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory

        let base = appSupport.appendingPathComponent("Clicher").appendingPathComponent("history")
        self.historyDirectory = base
        self.thumbnailDirectory = base.appendingPathComponent("thumbnails")
        self.indexURL = base.appendingPathComponent("index.json")
        self.maxEntries = maxEntries

        try? FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        loadIndex()
    }

    /// テスト用: カスタムディレクトリ
    public init(directory: URL, maxEntries: Int = 100) {
        self.historyDirectory = directory
        self.thumbnailDirectory = directory.appendingPathComponent("thumbnails")
        self.indexURL = directory.appendingPathComponent("index.json")
        self.maxEntries = maxEntries

        try? FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        loadIndex()
    }

    // MARK: - Public API

    /// 全履歴を取得（新しい順）
    public func allEntries() -> [CaptureHistoryEntry] {
        entries.sorted { $0.timestamp > $1.timestamp }
    }

    /// キャプチャ結果を履歴に追加
    public func add(image: CGImage, mode: CaptureMode, filePath: String? = nil) {
        let imageWidth = image.width
        let imageHeight = image.height
        let thumbnailName = "\(UUID().uuidString).png"
        let thumbnailURL = thumbnailDirectory.appendingPathComponent(thumbnailName)

        // autoreleasepool でサムネイル生成後に中間オブジェクトを即時解放
        autoreleasepool {
            if let thumbnailImage = createThumbnail(from: image, maxWidth: 200) {
                savePNG(thumbnailImage, to: thumbnailURL)
            }
        }

        let entry = CaptureHistoryEntry(
            mode: mode,
            width: imageWidth,
            height: imageHeight,
            filePath: filePath,
            thumbnailPath: thumbnailURL.path
        )

        entries.append(entry)

        // 上限を超えたら古いものを削除
        while entries.count > maxEntries {
            let oldest = entries.removeFirst()
            try? FileManager.default.removeItem(atPath: oldest.thumbnailPath)
        }

        saveIndex()
        Logger.app.info("キャプチャ履歴追加: \(entry.mode) \(entry.sizeLabel)")
    }

    /// 履歴を削除
    public func delete(_ entry: CaptureHistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        try? FileManager.default.removeItem(atPath: entry.thumbnailPath)
        saveIndex()
    }

    /// 全履歴をクリア
    public func clearAll() {
        for entry in entries {
            try? FileManager.default.removeItem(atPath: entry.thumbnailPath)
        }
        entries.removeAll()
        saveIndex()
    }

    /// サムネイル画像を読み込み
    public func loadThumbnail(for entry: CaptureHistoryEntry) -> NSImage? {
        NSImage(contentsOfFile: entry.thumbnailPath)
    }

    // MARK: - Private

    private func loadIndex() {
        guard let data = try? Data(contentsOf: indexURL) else { return }
        do {
            entries = try JSONDecoder().decode([CaptureHistoryEntry].self, from: data)
        } catch {
            Logger.app.error("履歴インデックスのデコード失敗: \(error)")
            // バックアップしてリセット
            let backupURL = indexURL.deletingPathExtension().appendingPathExtension("backup.json")
            try? FileManager.default.copyItem(at: indexURL, to: backupURL)
            entries = []
            onError?(L10n.error)
        }
    }

    private func saveIndex() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: indexURL)
        } catch {
            Logger.app.error("履歴インデックスの保存失敗: \(error)")
            onError?(L10n.saveFailed)
        }
    }

    private func createThumbnail(from image: CGImage, maxWidth: Int) -> CGImage? {
        let scale = CGFloat(maxWidth) / CGFloat(image.width)
        guard scale < 1 else { return image }

        let width = maxWidth
        let height = Int(CGFloat(image.height) * scale)

        guard let ctx = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private func savePNG(_ image: CGImage, to url: URL) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil
        ) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}
