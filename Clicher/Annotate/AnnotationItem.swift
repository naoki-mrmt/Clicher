import AppKit

/// アノテーション要素の種類
enum AnnotationToolType: String, CaseIterable, Identifiable, Sendable {
    case arrow
    case rectangle
    case ellipse
    case line
    case text
    case pixelate
    case highlight
    case counter
    case pencil
    case crop

    var id: String { rawValue }

    var label: String {
        switch self {
        case .arrow: "矢印"
        case .rectangle: "矩形"
        case .ellipse: "楕円"
        case .line: "線"
        case .text: "テキスト"
        case .pixelate: "モザイク"
        case .highlight: "ハイライト"
        case .counter: "カウンター"
        case .pencil: "ペンシル"
        case .crop: "クロップ"
        }
    }

    var systemImage: String {
        switch self {
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "oval"
        case .line: "line.diagonal"
        case .text: "textformat"
        case .pixelate: "mosaic.fill"
        case .highlight: "highlighter"
        case .counter: "number.circle"
        case .pencil: "pencil.and.scribble"
        case .crop: "crop"
        }
    }
}

/// 描画スタイル設定
struct AnnotationStyle: Equatable, Sendable {
    var strokeColor: NSColor = .systemRed
    var fillColor: NSColor = .clear
    var lineWidth: CGFloat = 3.0
    var fontSize: CGFloat = 24.0
    var fontName: String = ".AppleSystemUIFont"
    var isFilled: Bool = false
    var cornerRadius: CGFloat = 0
}

/// 1つのアノテーション要素
final class AnnotationItem: Identifiable {
    let id = UUID()
    let toolType: AnnotationToolType
    var style: AnnotationStyle
    var startPoint: CGPoint
    var endPoint: CGPoint
    var points: [CGPoint] // ペンシル用の複数ポイント
    var text: String // テキストツール用
    var counterNumber: Int // カウンター用

    init(
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

    /// バウンディングボックス
    var boundingRect: CGRect {
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
