public enum StatusLabels {
    public static let cpuPrefix = "C"
    public static let memoryPrefix = "R"
    public static let temperaturePrefix = ""
    public static let separator = " "
    public static let figureSpace = "\u{2007}"
    public static let minimumDigits = 2

    public static func text(for segment: StatusSegment, value: Double?) -> String? {
        switch segment {
        case .animation: nil
        case .cpu: labeled(cpuPrefix, UsageFormatter.number(value))
        case .memory: labeled(memoryPrefix, UsageFormatter.number(value))
        case .temperature: labeled(temperaturePrefix, UsageFormatter.temperature(value))
        }
    }

    private static func labeled(_ prefix: String, _ value: String) -> String {
        let padded = paddedToMinimumDigits(value)
        return prefix.isEmpty ? padded : prefix + separator + padded
    }

    private static func paddedToMinimumDigits(_ value: String) -> String {
        let digitCount = value.prefix { $0.isNumber }.count
        guard digitCount > 0, digitCount < minimumDigits else { return value }
        return String(repeating: figureSpace, count: minimumDigits - digitCount) + value
    }
}
