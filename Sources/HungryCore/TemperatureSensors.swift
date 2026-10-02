public struct SensorKeys: Equatable, Sendable {
    public var cpu: [String]
    public var gpu: [String]

    public init(cpu: [String], gpu: [String]) {
        self.cpu = cpu
        self.gpu = gpu
    }

    public var isEmpty: Bool { cpu.isEmpty && gpu.isEmpty }
}

public enum TemperatureSensors {
    public static func keys(for family: ChipFamily) -> SensorKeys {
        switch family {
        case .m1:
            SensorKeys(
                cpu: ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T", "Tp0X", "Tp0b"],
                gpu: ["Tg05", "Tg0D", "Tg0L", "Tg0T"]
            )
        case .m2:
            SensorKeys(
                cpu: ["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0X", "Tp0b", "Tp0f", "Tp0j", "Tp1h", "Tp1l", "Tp1p", "Tp1t"],
                gpu: ["Tg0f", "Tg0j"]
            )
        case .m3:
            SensorKeys(
                cpu: ["Te05", "Te0L", "Te0P", "Te0S", "Tf04", "Tf09", "Tf0A", "Tf0B", "Tf0D", "Tf0E", "Tf44", "Tf49", "Tf4A", "Tf4B", "Tf4D", "Tf4E"],
                gpu: ["Tf14", "Tf18", "Tf19", "Tf1A", "Tf24", "Tf28", "Tf29", "Tf2A"]
            )
        case .m4:
            SensorKeys(
                cpu: ["Te05", "Te09", "Te0H", "Te0S", "Tp01", "Tp05", "Tp09", "Tp0D", "Tp0V", "Tp0Y", "Tp0b", "Tp0e"],
                gpu: ["Tg0G", "Tg0H", "Tg0K", "Tg0L", "Tg0d", "Tg0e", "Tg0j", "Tg0k", "Tg1U", "Tg1k"]
            )
        }
    }

    public static let smoothingWeight = 0.3

    public static func hottest(_ values: [Double]) -> Double? {
        values.filter { $0.isFinite && $0 > 0 && $0 < 150 }.max()
    }

    public static func smooth(previous: TemperatureReading?, new: TemperatureReading?) -> TemperatureReading? {
        guard let new else { return previous }
        return TemperatureReading(
            cpu: smooth(previous?.cpu, new.cpu),
            gpu: smooth(previous?.gpu, new.gpu)
        )
    }

    private static func smooth(_ previous: Double?, _ new: Double?) -> Double? {
        guard let new else { return previous }
        guard let previous else { return new }
        return (1 - smoothingWeight) * previous + smoothingWeight * new
    }
}
