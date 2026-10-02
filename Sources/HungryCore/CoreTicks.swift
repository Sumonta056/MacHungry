public struct CoreTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var nice: UInt32
    public var idle: UInt32

    public init(user: UInt32, system: UInt32, nice: UInt32, idle: UInt32) {
        self.user = user
        self.system = system
        self.nice = nice
        self.idle = idle
    }
}
