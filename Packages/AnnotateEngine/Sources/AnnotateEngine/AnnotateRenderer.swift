import AppKit
import CoreImage
import OSLog
import SharedModels

/// アノテーション要素を CGContext に描画するレンダラー
public enum AnnotateRenderer {
    /// 全アノテーション要素を描画
    public static func render(items: [AnnotationItem], in context: CGContext, size: CGSize, originalImage: CGImage? = nil) {
        for item in items {
            render(item: item, in: context, size: size, originalImage: originalImage)
        }
    }

    /// 単一アノテーション要素を描画
    public static func render(item: AnnotationItem, in context: CGContext, size: CGSize, originalImage: CGImage? = nil) {
        context.saveGState()
        defer { context.restoreGState() }

        switch item.toolType {
        case .arrow:
            drawArrow(item, in: context)
        case .rectangle:
            drawRectangle(item, in: context)
        case .ellipse:
            drawEllipse(item, in: context)
        case .line:
            drawLine(item, in: context)
        case .text:
            drawText(item, in: context)
        case .pixelate:
            drawPixelate(item, in: context, size: size, originalImage: originalImage)
        case .highlight:
            drawHighlight(item, in: context)
        case .counter:
            drawCounter(item, in: context)
        case .pencil:
            drawPencil(item, in: context)
        case .crop:
            break // クロップは最終エクスポート時に適用
        }
    }

    // MARK: - Arrow

    private static func drawArrow(_ item: AnnotationItem, in ctx: CGContext) {
        let start = item.startPoint
        let end = item.endPoint

        ctx.setStrokeColor(item.style.strokeColor.cgColor)
        ctx.setLineWidth(item.style.lineWidth)
        ctx.setLineCap(.round)

        // 線本体
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()

        // 矢印の頭
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(item.style.lineWidth * 4, 12)
        let arrowAngle: CGFloat = .pi / 6

        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        ctx.setFillColor(item.style.strokeColor.cgColor)
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }

    // MARK: - Rectangle

    private static func drawRectangle(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = item.boundingRect

        if item.style.isFilled {
            ctx.setFillColor(item.style.strokeColor.withAlphaComponent(0.3).cgColor)
            if item.style.cornerRadius > 0 {
                let path = CGPath(
                    roundedRect: rect,
                    cornerWidth: item.style.cornerRadius,
                    cornerHeight: item.style.cornerRadius,
                    transform: nil
                )
                ctx.addPath(path)
                ctx.fillPath()
            } else {
                ctx.fill(rect)
            }
        }

        ctx.setStrokeColor(item.style.strokeColor.cgColor)
        ctx.setLineWidth(item.style.lineWidth)
        if item.style.cornerRadius > 0 {
            let path = CGPath(
                roundedRect: rect,
                cornerWidth: item.style.cornerRadius,
                cornerHeight: item.style.cornerRadius,
                transform: nil
            )
            ctx.addPath(path)
            ctx.strokePath()
        } else {
            ctx.stroke(rect)
        }
    }

    // MARK: - Ellipse

    private static func drawEllipse(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = item.boundingRect

        if item.style.isFilled {
            ctx.setFillColor(item.style.strokeColor.withAlphaComponent(0.3).cgColor)
            ctx.fillEllipse(in: rect)
        }

        ctx.setStrokeColor(item.style.strokeColor.cgColor)
        ctx.setLineWidth(item.style.lineWidth)
        ctx.strokeEllipse(in: rect)
    }

    // MARK: - Line

    private static func drawLine(_ item: AnnotationItem, in ctx: CGContext) {
        ctx.setStrokeColor(item.style.strokeColor.cgColor)
        ctx.setLineWidth(item.style.lineWidth)
        ctx.setLineCap(.round)
        ctx.move(to: item.startPoint)
        ctx.addLine(to: item.endPoint)
        ctx.strokePath()
    }

    // MARK: - Text

    private static func drawText(_ item: AnnotationItem, in ctx: CGContext) {
        guard !item.text.isEmpty else { return }

        let font = NSFont(name: item.style.fontName, size: item.style.fontSize)
            ?? NSFont.systemFont(ofSize: item.style.fontSize)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: item.style.strokeColor,
        ]

        let nsString = item.text as NSString

        // isFlipped=true の座標系でテキストを描画
        let drawPoint = CGPoint(
            x: item.startPoint.x,
            y: item.startPoint.y
        )

        // NSGraphicsContext 経由で描画（flipped=true で座標系を合わせる）
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.current = nsCtx
        nsString.draw(at: drawPoint, withAttributes: attributes)
    }

    // MARK: - Pixelate

    private static func drawPixelate(_ item: AnnotationItem, in ctx: CGContext, size: CGSize, originalImage: CGImage? = nil) {
        let rect = item.boundingRect
        guard rect.width > 0, rect.height > 0 else { return }

        let blockSize: CGFloat = 12

        // キャッシュキーを生成（位置とサイズが同じならキャッシュ再利用）
        let cacheKey = "\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"

        // キャッシュがあればそのまま描画
        if let cached = item.pixelateCache, item.pixelateCacheKey == cacheKey {
            ctx.draw(cached, in: rect)
            return
        }

        guard let originalImage else {
            drawPixelateFallback(rect: rect, blockSize: blockSize, in: ctx)
            return
        }

        // モザイク画像をオフスクリーンで生成
        let pixelateImage = generatePixelateImage(
            rect: rect, blockSize: blockSize, size: size, originalImage: originalImage
        )

        if let pixelateImage {
            // キャッシュに保存
            item.pixelateCache = pixelateImage
            item.pixelateCacheKey = cacheKey
            ctx.draw(pixelateImage, in: rect)
        } else {
            drawPixelateFallback(rect: rect, blockSize: blockSize, in: ctx)
        }
    }

    /// モザイク画像をオフスクリーンで生成
    private static func generatePixelateImage(
        rect: CGRect, blockSize: CGFloat, size: CGSize, originalImage: CGImage
    ) -> CGImage? {
        let imgW = CGFloat(originalImage.width)
        let imgH = CGFloat(originalImage.height)
        guard size.width > 0, size.height > 0 else { return nil }
        let scaleX = imgW / size.width
        let scaleY = imgH / size.height

        let flippedY = imgH - (rect.origin.y + rect.height) * scaleY
        let cropRect = CGRect(
            x: max(0, rect.origin.x * scaleX),
            y: max(0, flippedY),
            width: min(rect.width * scaleX, imgW),
            height: min(rect.height * scaleY, imgH)
        )

        guard let croppedImage = originalImage.cropping(to: cropRect),
              let dataProvider = croppedImage.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else { return nil }

        let bpp = croppedImage.bitsPerPixel / 8
        guard bpp >= 3 else { return nil }
        let rowBytes = croppedImage.bytesPerRow
        let cropW = croppedImage.width
        let cropH = croppedImage.height
        guard cropW > 0, cropH > 0 else { return nil }

        let alphaInfo = croppedImage.alphaInfo
        let rOffset: Int
        let gOffset: Int
        let bOffset: Int
        switch alphaInfo {
        case .premultipliedFirst, .first, .noneSkipFirst:
            rOffset = 1; gOffset = 2; bOffset = 3
        default:
            rOffset = 0; gOffset = 1; bOffset = 2
        }

        let w = Int(rect.width)
        let h = Int(rect.height)
        guard let offCtx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        // オフスクリーンは左下原点だが、ここではローカル座標で描画
        let blockScaleX = CGFloat(cropW) / rect.width
        let blockScaleY = CGFloat(cropH) / rect.height

        var y: CGFloat = 0
        while y < CGFloat(h) {
            var x: CGFloat = 0
            while x < CGFloat(w) {
                let bw = min(blockSize, CGFloat(w) - x)
                let bh = min(blockSize, CGFloat(h) - y)

                let px0 = Int(x * blockScaleX)
                let py0 = Int(y * blockScaleY)
                let px1 = min(Int((x + bw) * blockScaleX), cropW)
                let py1 = min(Int((y + bh) * blockScaleY), cropH)

                var totalR = 0, totalG = 0, totalB = 0, count = 0
                let stepY = max(1, (py1 - py0) / 4)
                let stepX = max(1, (px1 - px0) / 4)
                for py in stride(from: py0, to: py1, by: stepY) {
                    for px in stride(from: px0, to: px1, by: stepX) {
                        let offset = py * rowBytes + px * bpp
                        let maxChannelOffset = max(rOffset, gOffset, bOffset)
                        guard offset + maxChannelOffset < CFDataGetLength(data) else { continue }
                        totalR += Int(ptr[offset + rOffset])
                        totalG += Int(ptr[offset + gOffset])
                        totalB += Int(ptr[offset + bOffset])
                        count += 1
                    }
                }

                if count > 0 {
                    let color = CGColor(
                        red: CGFloat(totalR) / CGFloat(count) / 255.0,
                        green: CGFloat(totalG) / CGFloat(count) / 255.0,
                        blue: CGFloat(totalB) / CGFloat(count) / 255.0,
                        alpha: 1.0
                    )
                    offCtx.setFillColor(color)
                } else {
                    offCtx.setFillColor(CGColor(gray: 0.5, alpha: 0.8))
                }

                offCtx.fill(CGRect(x: x, y: CGFloat(h) - y - bh, width: bw, height: bh))
                x += blockSize
            }
            y += blockSize
        }

        return offCtx.makeImage()
    }

    private static func drawPixelateFallback(rect: CGRect, blockSize: CGFloat, in ctx: CGContext) {
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let blockRect = CGRect(
                    x: x, y: y,
                    width: min(blockSize, rect.maxX - x),
                    height: min(blockSize, rect.maxY - y)
                )
                let gray = CGFloat.random(in: 0.3...0.7)
                ctx.setFillColor(CGColor(gray: gray, alpha: 0.8))
                ctx.fill(blockRect)
                x += blockSize
            }
            y += blockSize
        }
    }

    // MARK: - Highlight

    private static func drawHighlight(_ item: AnnotationItem, in ctx: CGContext) {
        let rect = item.boundingRect
        ctx.setFillColor(item.style.strokeColor.withAlphaComponent(0.35).cgColor)
        ctx.fill(rect)
    }

    // MARK: - Counter

    private static func drawCounter(_ item: AnnotationItem, in ctx: CGContext) {
        let center = item.startPoint
        let radius: CGFloat = 14

        // 円の背景
        ctx.setFillColor(item.style.strokeColor.cgColor)
        ctx.fillEllipse(in: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        ))

        // 番号テキスト
        let text = "\(item.counterNumber)" as NSString
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attributes)
        let drawPoint = CGPoint(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2
        )

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
        NSGraphicsContext.current = nsCtx
        text.draw(at: drawPoint, withAttributes: attributes)
    }

    // MARK: - Pencil

    private static func drawPencil(_ item: AnnotationItem, in ctx: CGContext) {
        guard item.points.count >= 2 else { return }

        ctx.setStrokeColor(item.style.strokeColor.cgColor)
        ctx.setLineWidth(item.style.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        let pts = item.points

        if pts.count == 2 {
            ctx.move(to: pts[0])
            ctx.addLine(to: pts[1])
            ctx.strokePath()
            return
        }

        // Catmull-Rom スプライン補間でスムーズな曲線
        ctx.move(to: pts[0])
        for i in 0..<pts.count - 1 {
            let p0 = pts[max(0, i - 1)]
            let p1 = pts[i]
            let p2 = pts[min(pts.count - 1, i + 1)]
            let p3 = pts[min(pts.count - 1, i + 2)]

            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0,
                y: p1.y + (p2.y - p0.y) / 6.0
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0,
                y: p2.y - (p3.y - p1.y) / 6.0
            )

            ctx.addCurve(to: p2, control1: cp1, control2: cp2)
        }
        ctx.strokePath()
    }
}
