import SwiftUI

/// Annotateエディタの状態管理（Undo/Redo含む）
@Observable
final class AnnotateDocument {
    let originalImage: CGImage
    private(set) var annotations: [Annotation] = []
    private var undoStack: [[Annotation]] = []
    private var redoStack: [[Annotation]] = []

    var currentTool: ToolType = .arrow
    var currentStyle: AnnotationStyle = AnnotationStyle()
    var activeAnnotation: Annotation?
    private var counterValue = 1

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    init(image: CGImage) {
        self.originalImage = image
    }

    // MARK: - Annotation Management

    /// 新しいアノテーションを開始
    func beginAnnotation(at point: CGPoint) {
        var annotation = Annotation(
            toolType: currentTool,
            startPoint: point,
            endPoint: point,
            style: currentStyle
        )
        if currentTool == .pencil {
            annotation.points = [point]
        }
        if currentTool == .counter {
            annotation.counterNumber = counterValue
            counterValue += 1
        }
        activeAnnotation = annotation
    }

    /// アクティブなアノテーションを更新（ドラッグ中）
    func updateAnnotation(to point: CGPoint) {
        guard var annotation = activeAnnotation else { return }
        annotation.endPoint = point
        if annotation.toolType == .pencil {
            annotation.points.append(point)
        }
        activeAnnotation = annotation
    }

    /// アクティブなアノテーションを確定
    func commitAnnotation() {
        guard var annotation = activeAnnotation else { return }
        annotation.isCompleted = true
        pushUndo()
        annotations.append(annotation)
        activeAnnotation = nil
        redoStack.removeAll()
    }

    /// テキストアノテーションを追加
    func addTextAnnotation(at point: CGPoint, text: String) {
        var annotation = Annotation(
            toolType: .text,
            startPoint: point,
            endPoint: point,
            style: currentStyle,
            text: text
        )
        annotation.isCompleted = true
        pushUndo()
        annotations.append(annotation)
        redoStack.removeAll()
    }

    /// アノテーションを削除
    func removeAnnotation(_ annotation: Annotation) {
        pushUndo()
        annotations.removeAll { $0.id == annotation.id }
        redoStack.removeAll()
    }

    // MARK: - Undo / Redo

    func undo() {
        guard canUndo else { return }
        redoStack.append(annotations)
        annotations = undoStack.removeLast()
    }

    func redo() {
        guard canRedo else { return }
        undoStack.append(annotations)
        annotations = redoStack.removeLast()
    }

    private func pushUndo() {
        undoStack.append(annotations)
        // 最大 50 段階
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
    }

    // MARK: - Export

    /// アノテーション付き画像をレンダリング
    func renderFinalImage() -> CGImage? {
        let width = originalImage.width
        let height = originalImage.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // 元画像を描画
        context.draw(originalImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 各アノテーションを描画
        for annotation in annotations {
            drawAnnotation(annotation, in: context, imageSize: CGSize(width: width, height: height))
        }

        return context.makeImage()
    }

    private func drawAnnotation(_ annotation: Annotation, in context: CGContext, imageSize: CGSize) {
        context.saveGState()

        let strokeColor = NSColor(annotation.style.strokeColor).cgColor
        let fillColor = NSColor(annotation.style.fillColor).cgColor
        context.setStrokeColor(strokeColor)
        context.setFillColor(fillColor)
        context.setLineWidth(annotation.style.strokeWidth)

        switch annotation.toolType {
        case .arrow:
            drawArrow(annotation, in: context)
        case .rectangle:
            let rect = rectFrom(annotation)
            context.stroke(rect)
            if annotation.style.fillColor != .clear {
                context.fill(rect)
            }
        case .ellipse:
            let rect = rectFrom(annotation)
            context.strokeEllipse(in: rect)
            if annotation.style.fillColor != .clear {
                context.fillEllipse(in: rect)
            }
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
        case .text, .pixelate, .blur, .counter, .crop, .spotlight, .select:
            break // 特殊描画はビュー側で処理
        }

        context.restoreGState()
    }

    private func drawArrow(_ annotation: Annotation, in context: CGContext) {
        let start = annotation.startPoint
        let end = annotation.endPoint

        // 矢印の線
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // 矢印の先端
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 15
        let arrowAngle: CGFloat = .pi / 6

        let point1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let point2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )

        context.move(to: end)
        context.addLine(to: point1)
        context.move(to: end)
        context.addLine(to: point2)
        context.strokePath()
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
