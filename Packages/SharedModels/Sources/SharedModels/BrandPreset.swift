import Foundation
import CoreGraphics

/// ロゴの表示位置
public enum LogoPosition: String, Codable, CaseIterable, Identifiable, Sendable {
    case topLeft, topRight, bottomLeft, bottomRight, center

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .topLeft: "左上"
        case .topRight: "右上"
        case .bottomLeft: "左下"
        case .bottomRight: "右下"
        case .center: "中央"
        }
    }
}

/// Codable 対応のカラー（RGBA）
public struct CodableColor: Codable, Equatable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public var cgColor: CGColor {
        CGColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    public static let white = CodableColor(red: 1, green: 1, blue: 1)
    public static let black = CodableColor(red: 0, green: 0, blue: 0)
    public static let red = CodableColor(red: 1, green: 0, blue: 0)
    public static let blue = CodableColor(red: 0, green: 0, blue: 1)
}

/// グラデーション設定
public struct GradientConfig: Codable, Equatable, Sendable {
    public var startColor: CodableColor
    public var endColor: CodableColor
    public var angle: Double

    public init(
        startColor: CodableColor = .white,
        endColor: CodableColor = .blue,
        angle: Double = 135
    ) {
        self.startColor = startColor
        self.endColor = endColor
        self.angle = angle
    }
}

/// エクスポート設定
public struct ExportConfig: Codable, Equatable, Sendable {
    public var format: String // "png" or "jpeg"
    public var quality: Double // 0.0 - 1.0 (jpeg only)
    public var scale: Double // 1.0 = 1x, 2.0 = 2x

    public init(format: String = "png", quality: Double = 0.9, scale: Double = 2.0) {
        self.format = format
        self.quality = quality
        self.scale = scale
    }
}

/// ブランドプリセット
public struct BrandPreset: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var primaryColor: CodableColor
    public var secondaryColor: CodableColor
    public var accentColor: CodableColor
    public var logoImageData: Data?
    public var logoPosition: LogoPosition
    public var logoOpacity: Double
    public var fontName: String?
    public var fontSize: CGFloat
    public var backgroundGradient: GradientConfig?
    public var exportSettings: ExportConfig?
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String = "新規プリセット",
        primaryColor: CodableColor = .red,
        secondaryColor: CodableColor = .blue,
        accentColor: CodableColor = .white,
        logoImageData: Data? = nil,
        logoPosition: LogoPosition = .bottomRight,
        logoOpacity: Double = 0.8,
        fontName: String? = nil,
        fontSize: CGFloat = 24,
        backgroundGradient: GradientConfig? = nil,
        exportSettings: ExportConfig? = nil,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor
        self.accentColor = accentColor
        self.logoImageData = logoImageData
        self.logoPosition = logoPosition
        self.logoOpacity = logoOpacity
        self.fontName = fontName
        self.fontSize = fontSize
        self.backgroundGradient = backgroundGradient
        self.exportSettings = exportSettings
        self.isDefault = isDefault
    }
}
