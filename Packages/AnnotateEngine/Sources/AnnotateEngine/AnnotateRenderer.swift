import AppKit
import CoreImage
import OSLog
import SharedModels

/// アノテーション要素を CGContext に描画するレンダラー
public enum AnnotateRenderer {
    /// 全アノテーション要素を描画
    public static func render(items: [AnnotationItem], in context: CGContext, size: CGSize) {
        for item in items {
            render(item: item, in: context, size: size)
        }
    }

    /// 単一アノテーション要素を描画
    public static func render(item: AnnotationItem, in context: CGContext, size: CGSize) {
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
            drawPixelate(item, in: context, size: size)
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
        let size = nsString.size(withAttributes: attributes)

        // isFlipped=true の座標系でテキストを描画
        let drawPoint = CGPoint(
            x: item.startPoint.x,
            y: item.startPoint.y
        )

        // NSGraphicsContext 経由で描画（flipped=true で座標系を合わせる）
        NSGraphicsContext.saveGraphicsState()
        do {
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSGraphicsContext.current = nsCtx
            nsString.draw(at: drawPoint, withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Pixelate

    private static func drawPixelate(_ item: AnnotationItem, in ctx: CGContext, size: CGSize) {
        let rect = item.boundingRect
        guard rect.width > 0, rect.height > 0 else { return }

        let blockSize: CGFloat = 10

        // 矩形内をブロック化して描画
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                let blockRect = CGRect(
                    x: x, y: y,
                    width: min(blockSize, rect.maxX - x),
                    height: min(blockSize, rect.maxY - y)
                )
                // 簡易ピクセレーション: ランダムなグレー値で塗りつぶし
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
        do {
            let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: true)
            NSGraphicsContext.current = nsCtx
            text.draw(at: drawPoint, withAttributes: attributes)
        }
        NSGraphicsContext.restoreGraphicsState()
    }

    // MARK: - Pencil

    private static func drawPencil(_ item: AnnotationItem, in ctx: CGContext) {
        guard item.points.count >= 2 else { return }

        ctx.setStrokeColor(item.style.strokeColor.cgColor)
        ctx.setLineWidth(item.style.lineWidth)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        ctx.move(to: item.points[0])
        for i in 1..<item.points.count {
            ctx.addLine(to: item.points[i])
        }
        ctx.strokePath()
    }
}
