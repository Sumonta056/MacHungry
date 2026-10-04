import Foundation

public enum SpeedCurve {
    public static let minimumTimerInterval: TimeInterval = 0.03
    public static let replaceThreshold: TimeInterval = 0.005

    public static func smooth(previous: Double, new: Double) -> Double {
        0.7 * clampPercent(previous) + 0.3 * clampPercent(new)
    }

    public static func interval(forCPU cpu: Double, maxInterval: TimeInterval, minInterval: TimeInterval) -> TimeInterval {
        let share = clampPercent(cpu) / 100
        return max(maxInterval - (maxInterval - minInterval) * share, minimumTimerInterval)
    }

    public static func shouldReplaceTimer(current: TimeInterval, new: TimeInterval) -> Bool {
        abs(current - new) > replaceThreshold
    }

    static func clampPercent(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0), 100) : 0
    }
}
