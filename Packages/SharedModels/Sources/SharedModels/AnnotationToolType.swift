/// アノテーション要素の種類
public enum AnnotationToolType: String, CaseIterable, Identifiable, Sendable {
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

    public var id: String { rawValue }

    public var label: String {
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

    public var systemImage: String {
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
