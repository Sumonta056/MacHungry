import Foundation

public protocol AnimationTheme: Sendable {
    var id: String { get }
    var displayName: String { get }
    var frameCount: Int { get }
    var maxInterval: TimeInterval { get }
    var minInterval: TimeInterval { get }
}

public extension AnimationTheme {
    var frameNames: [String] {
        frameCount > 0 ? (1...frameCount).map { "frame-\($0)" } : []
    }

    func frameInterval(forCPU cpu: Double) -> TimeInterval {
        SpeedCurve.interval(forCPU: cpu, maxInterval: maxInterval, minInterval: minInterval)
    }
}
