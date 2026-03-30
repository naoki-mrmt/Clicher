import CoreGraphics
import OSLog

/// 画像の変換方向
public enum ImageOrientation: Sendable {
    case rotateLeft    // 90° 反時計回り
    case rotateRight   // 90° 時計回り
    case rotate180     // 180°
    case flipHorizontal // 左右反転
    case flipVertical   // 上下反転
}

/// 画像結合方向
public enum CombineDirection: Sendable {
    case horizontal // 横並び
    case vertical   // 縦並び
}

/// 画像ユーティリティ
public enum ImageUtilities {
    /// 複数画像を結合
    public static func combine(
        images: [CGImage],
        direction: CombineDirection,
        spacing: Int = 0
    ) -> CGImage? {
        guard !images.isEmpty else { return nil }
        guard images.count > 1 else { return images.first }

        let totalWidth: Int
        let totalHeight: Int

        switch direction {
        case .horizontal:
            totalWidth = images.reduce(0) { $0 + $1.width } + spacing * (images.count - 1)
            totalHeight = images.map(\.height).max() ?? 0
        case .vertical:
            totalWidth = images.map(\.width).max() ?? 0
            totalHeight = images.reduce(0) { $0 + $1.height } + spacing * (images.count - 1)
        }

        guard let ctx = CGContext(
            data: nil, width: totalWidth, height: totalHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        switch direction {
        case .horizontal:
            var x = 0
            for image in images {
                let y = (totalHeight - image.height) / 2
                ctx.draw(image, in: CGRect(x: x, y: y, width: image.width, height: image.height))
                x += image.width + spacing
            }
        case .vertical:
            // CGContext は左下原点なので上から描画
            var y = totalHeight
            for image in images {
                y -= image.height
                let x = (totalWidth - image.width) / 2
                ctx.draw(image, in: CGRect(x: x, y: y, width: image.width, height: image.height))
                y -= spacing
            }
        }

        Logger.capture.info("画像結合完了: \(images.count) 枚 → \(totalWidth)x\(totalHeight)")
        return ctx.makeImage()
    }

    /// 画像を変換（回転/反転）
    public static func transform(_ image: CGImage, orientation: ImageOrientation) -> CGImage? {
        let width = image.width
        let height = image.height

        let outputWidth: Int
        let outputHeight: Int

        switch orientation {
        case .rotateLeft, .rotateRight:
            outputWidth = height
            outputHeight = width
        default:
            outputWidth = width
            outputHeight = height
        }

        guard let ctx = CGContext(
            data: nil, width: outputWidth, height: outputHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        switch orientation {
        case .rotateRight:
            ctx.translateBy(x: CGFloat(outputWidth), y: 0)
            ctx.rotate(by: .pi / 2)
        case .rotateLeft:
            ctx.translateBy(x: 0, y: CGFloat(outputHeight))
            ctx.rotate(by: -.pi / 2)
        case .rotate180:
            ctx.translateBy(x: CGFloat(outputWidth), y: CGFloat(outputHeight))
            ctx.rotate(by: .pi)
        case .flipHorizontal:
            ctx.translateBy(x: CGFloat(outputWidth), y: 0)
            ctx.scaleBy(x: -1, y: 1)
        case .flipVertical:
            ctx.translateBy(x: 0, y: CGFloat(outputHeight))
            ctx.scaleBy(x: 1, y: -1)
        }

        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }
}
