import UniformTypeIdentifiers

/// 画像フォーマット
public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case jpeg

    public var id: String { rawValue }

    public var fileExtension: String { rawValue }

    public var utType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        }
    }

    public var label: String {
        rawValue.uppercased()
    }
}
