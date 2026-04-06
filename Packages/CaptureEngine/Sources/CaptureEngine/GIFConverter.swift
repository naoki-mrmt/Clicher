import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import OSLog
import Utilities

/// MP4 → GIF 変換ユーティリティ
public enum GIFConverter {
    /// MP4 ファイルを GIF に変換
    /// - Parameters:
    ///   - videoURL: 変換元の MP4 ファイル
    ///   - outputURL: 出力先の GIF ファイル（nil の場合は同ディレクトリに .gif で生成）
    ///   - fps: GIF のフレームレート（デフォルト 10fps）
    ///   - width: GIF の幅（nil で元のサイズ）
    /// - Returns: 生成された GIF ファイルの URL
    public static func convert(
        videoURL: URL,
        outputURL: URL? = nil,
        fps: Int = 10,
        width: Int? = nil
    ) async throws -> URL {
        let asset = AVURLAsset(url: videoURL)
        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)

        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw GIFError.noVideoTrack
        }

        let naturalSize = try await track.load(.naturalSize)
        let targetWidth = width ?? Int(naturalSize.width)
        let scale = CGFloat(targetWidth) / naturalSize.width
        let targetHeight = Int(naturalSize.height * scale)

        let gifURL = outputURL ?? videoURL.deletingPathExtension().appendingPathExtension("gif")

        guard let destination = CGImageDestinationCreateWithURL(
            gifURL as CFURL,
            UTType.gif.identifier as CFString,
            Int(durationSeconds * Double(fps)),
            nil
        ) else {
            throw GIFError.cannotCreateDestination
        }

        // GIF のループ設定
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0, // 無限ループ
            ],
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        let frameDelay = 1.0 / Double(fps)
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
            ],
        ]

        // フレームを抽出して GIF に追加
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: targetWidth, height: targetHeight)

        let totalFrames = Int(durationSeconds * Double(fps))
        var addedFrames = 0
        for i in 0..<totalFrames {
            let time = CMTime(seconds: Double(i) * frameDelay, preferredTimescale: 600)
            do {
                let (image, _) = try await generator.image(at: time)
                CGImageDestinationAddImage(destination, image, frameProperties as CFDictionary)
                addedFrames += 1
            } catch {
                Logger.capture.warning("GIF フレーム \(i) の抽出に失敗: \(error)")
            }
        }

        guard addedFrames > 0 else {
            throw GIFError.noFramesExtracted
        }

        guard CGImageDestinationFinalize(destination) else {
            throw GIFError.finalizeFailed
        }

        Logger.capture.info("GIF 変換完了: \(totalFrames) フレーム → \(gifURL.lastPathComponent)")
        return gifURL
    }
}

/// GIF 変換エラー
public enum GIFError: Error, Sendable, LocalizedError {
    case noVideoTrack
    case cannotCreateDestination
    case noFramesExtracted
    case finalizeFailed

    public var errorDescription: String? {
        switch self {
        case .noVideoTrack: "動画トラックが見つかりません"
        case .cannotCreateDestination: "GIF ファイルを作成できません"
        case .noFramesExtracted: "フレームの抽出に失敗しました"
        case .finalizeFailed: "GIF の書き出しに失敗しました"
        }
    }
}
