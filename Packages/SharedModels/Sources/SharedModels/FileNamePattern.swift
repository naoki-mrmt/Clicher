/// ファイル命名パターン
public enum FileNamePattern: String, CaseIterable, Identifiable, Sendable {
    case dateTime = "datetime"
    case sequential = "sequential"
    case custom = "custom"

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .dateTime: "日時 (Clicher_2024-01-01_12-00-00)"
        case .sequential: "連番 (Clicher_001)"
        case .custom: "カスタム"
        }
    }
}
