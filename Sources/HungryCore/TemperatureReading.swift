public struct TemperatureReading: Equatable, Sendable {
    public var cpu: Double?
    public var gpu: Double?

    public init(cpu: Double?, gpu: Double?) {
        self.cpu = cpu
        self.gpu = gpu
    }
}
