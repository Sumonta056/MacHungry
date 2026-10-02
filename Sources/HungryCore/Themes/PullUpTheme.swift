import Foundation

public struct PullUpTheme: AnimationTheme {
    public let id = "pullup"
    public let displayName = "Pull-ups"
    public let frameCount = 6
    public let maxInterval: TimeInterval = 0.25
    public let minInterval: TimeInterval = 0.04

    public init() {}
}
