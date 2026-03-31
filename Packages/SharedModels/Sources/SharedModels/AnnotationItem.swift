import CoreGraphics
import Foundation

/// 1つのアノテーション要素
public final class AnnotationItem: Identifiable {
    public let id = UUID()
    public let toolType: AnnotationToolType
    public var style: AnnotationStyle
    public var startPoint: CGPoint
    public var endPoint: CGPoint
    public var points: [CGPoint]
    public var text: String
    public var counterNumber: Int

    public init(
        toolType: AnnotationToolType,
        style: AnnotationStyle = AnnotationStyle(),
        startPoint: CGPoint = .zero,
        endPoint: CGPoint = .zero,
        points: [CGPoint] = [],
        text: String = "",
        counterNumber: Int = 0
    ) {
        self.toolType = toolType
        self.style = style
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.points = points
        self.text = text
        self.counterNumber = counterNumber
    }

    /// ディープコピーを作成（Undo スタック保存用）
    public func copy() -> AnnotationItem {
        AnnotationItem(
            toolType: toolType,
            style: style,
            startPoint: startPoint,
            endPoint: endPoint,
            points: points,
            text: text,
            counterNumber: counterNumber
        )
    }

    /// バウンディングボックス
    public var boundingRect: CGRect {
        switch toolType {
        case .pencil:
            guard let first = points.first else { return .zero }
            var minX = first.x, minY = first.y
            var maxX = first.x, maxY = first.y
            for p in points {
                minX = min(minX, p.x)
                minY = min(minY, p.y)
                maxX = max(maxX, p.x)
                maxY = max(maxY, p.y)
            }
            let padding = style.lineWidth / 2
            return CGRect(
                x: minX - padding, y: minY - padding,
                width: maxX - minX + style.lineWidth,
                height: maxY - minY + style.lineWidth
            )
        default:
            return CGRect(
                x: min(startPoint.x, endPoint.x),
                y: min(startPoint.y, endPoint.y),
                width: abs(endPoint.x - startPoint.x),
                height: abs(endPoint.y - startPoint.y)
            )
        }
    }
}
