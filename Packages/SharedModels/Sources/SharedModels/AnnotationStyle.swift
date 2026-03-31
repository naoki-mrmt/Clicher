import AppKit

/// 描画スタイル設定
public struct AnnotationStyle: Equatable, @unchecked Sendable {
    public var strokeColor: NSColor
    public var fillColor: NSColor
    public var lineWidth: CGFloat
    public var fontSize: CGFloat
    public var fontName: String
    public var isFilled: Bool
    public var cornerRadius: CGFloat

    public init(
        strokeColor: NSColor = .systemRed,
        fillColor: NSColor = .clear,
        lineWidth: CGFloat = 3.0,
        fontSize: CGFloat = 24.0,
        fontName: String = ".AppleSystemUIFont",
        isFilled: Bool = false,
        cornerRadius: CGFloat = 0
    ) {
        self.strokeColor = strokeColor
        self.fillColor = fillColor
        self.lineWidth = lineWidth
        self.fontSize = fontSize
        self.fontName = fontName
        self.isFilled = isFilled
        self.cornerRadius = cornerRadius
    }
}
