import Foundation
import SwiftUI

/// アノテーションツールの種類
enum ToolType: String, CaseIterable, Identifiable, Sendable {
    case select
    case arrow
    case rectangle
    case ellipse
    case line
    case text
    case pixelate
    case blur
    case highlighter
    case counter
    case pencil
    case crop
    case spotlight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .select: "Select"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .line: "Line"
        case .text: "Text"
        case .pixelate: "Pixelate"
        case .blur: "Blur"
        case .highlighter: "Highlighter"
        case .counter: "Counter"
        case .pencil: "Pencil"
        case .crop: "Crop"
        case .spotlight: "Spotlight"
        }
    }

    var iconName: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .text: "textformat"
        case .pixelate: "mosaic"
        case .blur: "aqi.medium"
        case .highlighter: "highlighter"
        case .counter: "number.circle"
        case .pencil: "pencil.tip"
        case .crop: "crop"
        case .spotlight: "light.max"
        }
    }
}

/// アノテーションのスタイル設定
struct AnnotationStyle: Sendable {
    var strokeColor: Color = .red
    var fillColor: Color = .clear
    var strokeWidth: CGFloat = 3
    var fontSize: CGFloat = 16
    var fontName: String = ".AppleSystemUIFont"
    var opacity: Double = 1.0
}

/// 個々のアノテーション要素
struct Annotation: Identifiable, Sendable {
    let id = UUID()
    let toolType: ToolType
    var startPoint: CGPoint
    var endPoint: CGPoint
    var style: AnnotationStyle
    var text: String = ""
    var points: [CGPoint] = [] // ペンシル用
    var counterNumber: Int = 0
    var isCompleted: Bool = false
}
