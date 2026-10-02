import Foundation

public struct CatTheme: AnimationTheme {
    public let id = "cat"
    public let displayName = "Cat"
    public let frameCount = 5
    public let maxInterval: TimeInterval = 0.20
    public let minInterval: TimeInterval = 0.03

    public init() {}
}
