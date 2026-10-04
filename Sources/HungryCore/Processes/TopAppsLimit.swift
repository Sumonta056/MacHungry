public enum TopAppsLimit: Int, CaseIterable, Sendable {
    case ten = 10
    case twenty = 20

    public static let `default`: TopAppsLimit = .ten

    public init(stored: Int?) {
        self = stored.flatMap(TopAppsLimit.init(rawValue:)) ?? .default
    }
}
