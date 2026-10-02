import Foundation

public struct PushUpTheme: AnimationTheme {
    public let id = "pushup"
    public let displayName = "Push-ups"
    public let frameCount = 6
    public let maxInterval: TimeInterval = 0.25
    public let minInterval: TimeInterval = 0.04

    public init() {}
}
