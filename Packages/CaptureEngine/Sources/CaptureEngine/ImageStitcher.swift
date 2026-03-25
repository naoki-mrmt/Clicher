import CoreGraphics
import OSLog
import Utilities

/// 複数画像を縦方向にスティッチするユーティリティ
public enum ImageStitcher {
    /// 画像を縦方向に結合
    /// - Parameters:
    ///   - images: 結合する画像の配列（上から下の順）
    ///   - overlap: 画像間のオーバーラップピクセル数
    /// - Returns: 結合された画像
    public static func stitchVertically(images: [CGImage], overlap: Int) -> CGImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images.first }

        let width = images[0].width
        let totalOverlap = overlap * (images.count - 1)
        let totalHeight = images.reduce(0) { $0 + $1.height } - totalOverlap

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // CGContext は左下原点。上から描画するために y を計算
        var currentY = totalHeight
        for image in images {
            currentY -= image.height
            let rect = CGRect(x: 0, y: currentY, width: width, height: image.height)
            ctx.draw(image, in: rect)
            currentY += overlap // オーバーラップ分を戻す
        }

        Logger.capture.info("画像スティッチ完了: \(images.count) フレーム → \(width)x\(totalHeight)")
        return ctx.makeImage()
    }
}
