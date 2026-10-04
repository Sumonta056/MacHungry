public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var cpuSeconds: Double
    public var path: String

    public init(pid: Int32, cpuSeconds: Double, path: String) {
        self.pid = pid
        self.cpuSeconds = cpuSeconds
        self.path = path
    }
}
