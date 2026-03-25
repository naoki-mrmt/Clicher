/// セルフタイマー設定
public enum TimerDelay: Int, CaseIterable, Identifiable, Sendable {
    case none = 0
    case threeSeconds = 3
    case fiveSeconds = 5
    case tenSeconds = 10

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .none: "なし"
        case .threeSeconds: "3秒"
        case .fiveSeconds: "5秒"
        case .tenSeconds: "10秒"
        }
    }
}
