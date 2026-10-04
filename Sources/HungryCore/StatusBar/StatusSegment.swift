public enum StatusSegment: String, CaseIterable, Sendable {
    case animation
    case cpu
    case memory
    case temperature

    public var title: String {
        switch self {
        case .animation: "Animation"
        case .cpu: "CPU"
        case .memory: "RAM"
        case .temperature: "Temperature"
        }
    }
}
