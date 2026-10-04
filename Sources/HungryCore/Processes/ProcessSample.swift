public struct ProcessSample: Equatable, Sendable {
    public var pid: Int32
    public var parentPid: Int32
    public var cpuSeconds: Double
    public var path: String

    public init(pid: Int32, parentPid: Int32 = 0, cpuSeconds: Double, path: String) {
        self.pid = pid
        self.parentPid = parentPid
        self.cpuSeconds = cpuSeconds
        self.path = path
    }
}
