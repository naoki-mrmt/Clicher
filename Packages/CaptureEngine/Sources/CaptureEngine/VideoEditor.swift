import AVFoundation
import OSLog
import Utilities

/// 動画の品質設定
public struct VideoQuality: Sendable {
    public var preset: String
    public var videoBitRate: Int?

    public static let high = VideoQuality(preset: AVAssetExportPresetHighestQuality)
    public static let medium = VideoQuality(preset: AVAssetExportPresetMediumQuality)
    public static let low = VideoQuality(preset: AVAssetExportPresetLowQuality)
    public static let hd720 = VideoQuality(preset: AVAssetExportPreset1280x720)
    public static let hd1080 = VideoQuality(preset: AVAssetExportPreset1920x1080)

    public init(preset: String, videoBitRate: Int? = nil) {
        self.preset = preset
        self.videoBitRate = videoBitRate
    }
}

/// 動画編集ユーティリティ
public enum VideoEditor {
    /// 動画をトリム（開始/終了時間を指定）
    public static func trim(
        videoURL: URL,
        startTime: Double,
        endTime: Double,
        outputURL: URL? = nil
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let totalSeconds = CMTimeGetSeconds(duration)

        let clampedStart = max(0, startTime)
        let clampedEnd = min(totalSeconds, endTime)

        guard clampedStart < clampedEnd else {
            throw VideoEditorError.invalidTimeRange
        }

        let start = CMTime(seconds: clampedStart, preferredTimescale: 600)
        let end = CMTime(seconds: clampedEnd, preferredTimescale: 600)
        let timeRange = CMTimeRange(start: start, end: end)

        let output = outputURL ?? generateOutputURL(from: videoURL, suffix: "trimmed")

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality) else {
            throw VideoEditorError.exporterCreationFailed
        }

        exporter.outputURL = output
        exporter.outputFileType = .mp4
        exporter.timeRange = timeRange

        await exporter.export()

        guard exporter.status == .completed else {
            throw VideoEditorError.exportFailed(exporter.error)
        }

        Logger.capture.info("動画トリム完了: \(clampedStart)s - \(clampedEnd)s → \(output.lastPathComponent)")
        return output
    }

    /// 動画の品質を変更（再エンコード）
    public static func changeQuality(
        videoURL: URL,
        quality: VideoQuality,
        outputURL: URL? = nil
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let output = outputURL ?? generateOutputURL(from: videoURL, suffix: "reencoded")

        guard let exporter = AVAssetExportSession(asset: asset, presetName: quality.preset) else {
            throw VideoEditorError.exporterCreationFailed
        }

        exporter.outputURL = output
        exporter.outputFileType = .mp4

        await exporter.export()

        guard exporter.status == .completed else {
            throw VideoEditorError.exportFailed(exporter.error)
        }

        Logger.capture.info("動画品質変更完了: \(quality.preset) → \(output.lastPathComponent)")
        return output
    }

    /// 動画の情報を取得
    public static func getInfo(videoURL: URL) async throws -> VideoInfo {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)

        var size = CGSize.zero
        var fps: Float = 0
        if let track = try await asset.loadTracks(withMediaType: .video).first {
            size = try await track.load(.naturalSize)
            fps = try await track.load(.nominalFrameRate)
        }

        let hasAudio = try await !asset.loadTracks(withMediaType: .audio).isEmpty

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int) ?? 0

        return VideoInfo(
            duration: CMTimeGetSeconds(duration),
            size: size,
            fps: fps,
            hasAudio: hasAudio,
            fileSize: fileSize
        )
    }

    private static func generateOutputURL(from url: URL, suffix: String) -> URL {
        let name = url.deletingPathExtension().lastPathComponent
        return url.deletingLastPathComponent()
            .appendingPathComponent("\(name)_\(suffix).mp4")
    }
}

/// 動画情報
public struct VideoInfo: Sendable {
    public let duration: Double
    public let size: CGSize
    public let fps: Float
    public let hasAudio: Bool
    public let fileSize: Int

    /// ファイルサイズを人間が読みやすい形式に
    public var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

/// 動画編集エラー
public enum VideoEditorError: Error, Sendable {
    case invalidTimeRange
    case exporterCreationFailed
    case exportFailed(Error?)
}
