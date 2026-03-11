import SwiftUI

/// Annotateのメインキャンバス（NSViewRepresentable）
struct AnnotateCanvasView: NSViewRepresentable {
    let document: AnnotateDocument

    func makeNSView(context: Context) -> AnnotateCanvasNSView {
        let view = AnnotateCanvasNSView(document: document)
        return view
    }

    func updateNSView(_ nsView: AnnotateCanvasNSView, context: Context) {
        nsView.document = document
        nsView.needsDisplay = true
    }
}

/// CoreGraphics で描画する NSView
final class AnnotateCanvasNSView: NSView {
    var document: AnnotateDocument

    init(document: AnnotateDocument) {
        self.document = document
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 元画像を描画
        let imageRect = CGRect(
            x: 0, y: 0,
            width: bounds.width,
            height: bounds.height
        )

        // isFlipped = true なので座標変換
        context.saveGState()
        let image = document.originalImage
        context.draw(image, in: imageRect)
        context.restoreGState()

        // 確定済みアノテーション
        for annotation in document.annotations {
            drawAnnotation(annotation, in: context)
        }

        // アクティブなアノテーション
        if let active = document.activeAnnotation {
            drawAnnotation(active, in: context)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        if document.currentTool == .text {
            // テキストツールはクリック位置にテキスト入力を開始
            showTextInput(at: point)
            return
        }

        document.beginAnnotation(at: point)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        document.updateAnnotation(to: point)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        document.commitAnnotation()
        needsDisplay = true
    }

    // MARK: - Drawing

    private func drawAnnotation(_ annotation: Annotation, in context: CGContext) {
        context.saveGState()

        let strokeColor = NSColor(annotation.style.strokeColor).cgColor
        let fillColor = NSColor(annotation.style.fillColor).cgColor
        context.setStrokeColor(strokeColor)
        context.setFillColor(fillColor)
        context.setLineWidth(annotation.style.strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        switch annotation.toolType {
        case .arrow:
            drawArrow(annotation, in: context)
        case .rectangle:
            let rect = rectFrom(annotation)
            if annotation.style.fillColor != .clear {
                context.fill(rect)
            }
            context.stroke(rect)
        case .ellipse:
            let rect = rectFrom(annotation)
            if annotation.style.fillColor != .clear {
                context.fillEllipse(in: rect)
            }
            context.strokeEllipse(in: rect)
        case .line:
            context.move(to: annotation.startPoint)
            context.addLine(to: annotation.endPoint)
            context.strokePath()
        case .pencil:
            guard let first = annotation.points.first else { break }
            context.move(to: first)
            for point in annotation.points.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        case .highlighter:
            context.setAlpha(0.3)
            let rect = rectFrom(annotation)
            context.setFillColor(strokeColor)
            context.fill(rect)
        case .counter:
            drawCounter(annotation, in: context)
        case .spotlight:
            drawSpotlight(annotation, in: context)
        case .pixelate:
            drawPixelate(annotation, in: context)
        case .blur:
            drawBlur(annotation, in: context)
        case .text:
            drawText(annotation, in: context)
        case .crop, .select:
            break
        }

        context.restoreGState()
    }

    private func drawArrow(_ annotation: Annotation, in context: CGContext) {
        let start = annotation.startPoint
        let end = annotation.endPoint

        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6

        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }

    private func drawCounter(_ annotation: Annotation, in context: CGContext) {
        let center = annotation.startPoint
        let radius: CGFloat = 14
        let circleRect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )

        let strokeColor = NSColor(annotation.style.strokeColor).cgColor
        context.setFillColor(strokeColor)
        context.fillEllipse(in: circleRect)

        // 数字
        let text = "\(annotation.counterNumber)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attrs)
        let textPoint = CGPoint(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2
        )

        // NSGraphicsContext を使用してテキスト描画
        NSGraphicsContext.saveGraphicsState()
        text.draw(at: textPoint, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawSpotlight(_ annotation: Annotation, in context: CGContext) {
        let rect = rectFrom(annotation)
        // 選択範囲以外を暗く
        context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(bounds)
        context.clear(rect)
    }

    private func drawPixelate(_ annotation: Annotation, in context: CGContext) {
        let rect = rectFrom(annotation)
        // モザイク効果（簡易版：ブロック化）
        let blockSize: CGFloat = 10
        context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
        var x = rect.minX
        while x < rect.maxX {
            var y = rect.minY
            while y < rect.maxY {
                let block = CGRect(x: x, y: y, width: blockSize, height: blockSize)
                context.fill(block)
                y += blockSize * 2
            }
            x += blockSize * 2
        }
    }

    private func drawBlur(_ annotation: Annotation, in context: CGContext) {
        let rect = rectFrom(annotation)
        context.setFillColor(NSColor.white.withAlphaComponent(0.6).cgColor)
        context.fill(rect)
    }

    private func drawText(_ annotation: Annotation, in context: CGContext) {
        guard !annotation.text.isEmpty else { return }
        let text = annotation.text as NSString
        let font = NSFont(name: annotation.style.fontName, size: annotation.style.fontSize)
            ?? NSFont.systemFont(ofSize: annotation.style.fontSize)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(annotation.style.strokeColor),
        ]
        NSGraphicsContext.saveGraphicsState()
        text.draw(at: annotation.startPoint, withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func showTextInput(at point: CGPoint) {
        let alert = NSAlert()
        alert.messageText = "Enter text"
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = ""
        alert.accessoryView = textField

        if alert.runModal() == .alertFirstButtonReturn {
            let text = textField.stringValue
            if !text.isEmpty {
                document.addTextAnnotation(at: point, text: text)
                needsDisplay = true
            }
        }
    }

    private func rectFrom(_ annotation: Annotation) -> CGRect {
        CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )
    }
}
