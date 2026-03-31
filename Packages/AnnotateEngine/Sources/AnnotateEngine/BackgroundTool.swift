import CoreGraphics
import AppKit
import OSLog
import Utilities

/// SNS サイズプリセット
public enum SNSSizePreset: String, CaseIterable, Identifiable, Sendable {
    case twitterPost = "twitter_post"
    case twitterHeader = "twitter_header"
    case instagramSquare = "instagram_square"
    case instagramStory = "instagram_story"
    case ogImage = "og_image"

    public var id: String { rawValue }

    public var size: CGSize {
        switch self {
        case .twitterPost: CGSize(width: 1200, height: 675)
        case .twitterHeader: CGSize(width: 1500, height: 500)
        case .instagramSquare: CGSize(width: 1080, height: 1080)
        case .instagramStory: CGSize(width: 1080, height: 1920)
        case .ogImage: CGSize(width: 1200, height: 630)
        }
    }

    public var label: String {
        switch self {
        case .twitterPost: "Twitter Post (1200x675)"
        case .twitterHeader: "Twitter Header (1500x500)"
        case .instagramSquare: "Instagram Square (1080x1080)"
        case .instagramStory: "Instagram Story (1080x1920)"
        case .ogImage: "OG Image (1200x630)"
        }
    }
}

/// 背景スタイル
public enum BackgroundStyle: Sendable {
    case solidColor(CGColor)
    case gradient(startColor: CGColor, endColor: CGColor, angle: CGFloat)
}

/// 背景設定
public struct BackgroundConfig: Sendable {
    public var style: BackgroundStyle
    public var padding: CGFloat
    public var cornerRadius: CGFloat
    public var targetSize: CGSize?
    public var shadowRadius: CGFloat
    public var shadowOpacity: CGFloat

    public init(
        style: BackgroundStyle = .solidColor(CGColor(gray: 0.95, alpha: 1)),
        padding: CGFloat = 40,
        cornerRadius: CGFloat = 12,
        targetSize: CGSize? = nil,
        shadowRadius: CGFloat = 0,
        shadowOpacity: CGFloat = 0.3
    ) {
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.targetSize = targetSize
        self.shadowRadius = shadowRadius
        self.shadowOpacity = shadowOpacity
    }
}

/// スクリーンショットに背景を追加するツール
public enum BackgroundTool {
    private static let colorSpace = CGColorSpaceCreateDeviceRGB()
    /// 画像に背景を適用
    public static func apply(to image: CGImage, config: BackgroundConfig) -> CGImage? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)
        let padding = config.padding

        // ターゲットサイズが指定されている場合はそれを使用
        let canvasWidth: Int
        let canvasHeight: Int

        if let targetSize = config.targetSize {
            canvasWidth = Int(targetSize.width)
            canvasHeight = Int(targetSize.height)
        } else {
            canvasWidth = Int(imageWidth + padding * 2)
            canvasHeight = Int(imageHeight + padding * 2)
        }

        guard let ctx = CGContext(
            data: nil,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        let canvasRect = CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight)

        // 背景を描画
        switch config.style {
        case .solidColor(let color):
            ctx.setFillColor(color)
            ctx.fill(canvasRect)

        case .gradient(let startColor, let endColor, let angle):
            drawGradient(
                in: ctx, rect: canvasRect,
                startColor: startColor, endColor: endColor, angle: angle
            )
        }

        // 画像を中央に配置
        let imageRect: CGRect
        if config.targetSize != nil {
            // ターゲットサイズ内でアスペクト比を保ってフィット
            let scale = min(
                (CGFloat(canvasWidth) - padding * 2) / imageWidth,
                (CGFloat(canvasHeight) - padding * 2) / imageHeight
            )
            let scaledWidth = imageWidth * scale
            let scaledHeight = imageHeight * scale
            imageRect = CGRect(
                x: (CGFloat(canvasWidth) - scaledWidth) / 2,
                y: (CGFloat(canvasHeight) - scaledHeight) / 2,
                width: scaledWidth,
                height: scaledHeight
            )
        } else {
            imageRect = CGRect(
                x: padding,
                y: padding,
                width: imageWidth,
                height: imageHeight
            )
        }

        // 角丸クリップ
        if config.cornerRadius > 0 {
            let path = CGPath(
                roundedRect: imageRect,
                cornerWidth: config.cornerRadius,
                cornerHeight: config.cornerRadius,
                transform: nil
            )
            ctx.addPath(path)
            ctx.clip()
        }

        // シャドウ
        if config.shadowRadius > 0 {
            ctx.setShadow(
                offset: CGSize(width: 0, height: -2),
                blur: config.shadowRadius,
                color: CGColor(gray: 0, alpha: config.shadowOpacity)
            )
        }

        ctx.draw(image, in: imageRect)

        Logger.capture.info("Background Tool 適用: \(canvasWidth)x\(canvasHeight)")
        return ctx.makeImage()
    }

    // MARK: - Private

    private static func drawGradient(
        in ctx: CGContext,
        rect: CGRect,
        startColor: CGColor,
        endColor: CGColor,
        angle: CGFloat
    ) {
        guard let gradient = CGGradient(
            colorsSpace: colorSpace,
            colors: [startColor, endColor] as CFArray,
            locations: [0, 1]
        ) else { return }

        let radians = angle * .pi / 180
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = max(rect.width, rect.height) / 2

        let startPoint = CGPoint(
            x: center.x - cos(radians) * radius,
            y: center.y - sin(radians) * radius
        )
        let endPoint = CGPoint(
            x: center.x + cos(radians) * radius,
            y: center.y + sin(radians) * radius
        )

        ctx.drawLinearGradient(
            gradient,
            start: startPoint,
            end: endPoint,
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
    }
}
