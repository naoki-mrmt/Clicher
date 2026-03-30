import CoreGraphics
import AppKit
import OSLog
import SharedModels

/// ロゴウォーターマークを画像に描画するユーティリティ
public enum WatermarkRenderer {
    /// 画像にブランドプリセットのロゴウォーターマークを挿入
    public static func apply(to image: CGImage, preset: BrandPreset) -> CGImage? {
        guard let logoData = preset.logoImageData,
              let logoNSImage = NSImage(data: logoData),
              let logoCGImage = logoNSImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return image // ロゴがなければ元画像をそのまま返す
        }

        let width = image.width
        let height = image.height

        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // 元画像を描画
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // ロゴサイズ（元画像の15%幅を上限）
        let maxLogoWidth = CGFloat(width) * 0.15
        let logoScale = min(maxLogoWidth / CGFloat(logoCGImage.width), 1.0)
        let logoWidth = CGFloat(logoCGImage.width) * logoScale
        let logoHeight = CGFloat(logoCGImage.height) * logoScale
        let padding: CGFloat = 16

        // 位置を計算
        let logoRect: CGRect
        switch preset.logoPosition {
        case .topLeft:
            logoRect = CGRect(x: padding, y: CGFloat(height) - logoHeight - padding, width: logoWidth, height: logoHeight)
        case .topRight:
            logoRect = CGRect(x: CGFloat(width) - logoWidth - padding, y: CGFloat(height) - logoHeight - padding, width: logoWidth, height: logoHeight)
        case .bottomLeft:
            logoRect = CGRect(x: padding, y: padding, width: logoWidth, height: logoHeight)
        case .bottomRight:
            logoRect = CGRect(x: CGFloat(width) - logoWidth - padding, y: padding, width: logoWidth, height: logoHeight)
        case .center:
            logoRect = CGRect(x: (CGFloat(width) - logoWidth) / 2, y: (CGFloat(height) - logoHeight) / 2, width: logoWidth, height: logoHeight)
        }

        // 不透明度を設定してロゴを描画
        ctx.setAlpha(preset.logoOpacity)
        ctx.draw(logoCGImage, in: logoRect)

        Logger.capture.info("ウォーターマーク挿入: \(preset.logoPosition.rawValue), opacity=\(preset.logoOpacity)")
        return ctx.makeImage()
    }
}
