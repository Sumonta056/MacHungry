import Darwin
import HungryCore

public struct TemperatureSampler {
    private let reader: SMCReader?
    private let keys: SensorKeys

    public init(brand: String = TemperatureSampler.cpuBrand()) {
        guard let family = ChipFamily.detect(brand: brand), let reader = SMCReader() else {
            self.reader = nil
            self.keys = SensorKeys(cpu: [], gpu: [])
            return
        }
        let table = TemperatureSensors.keys(for: family)
        self.reader = reader
        self.keys = SensorKeys(cpu: reader.floatKeys(from: table.cpu), gpu: reader.floatKeys(from: table.gpu))
    }

    public var isAvailable: Bool {
        reader != nil && !keys.isEmpty
    }

    public func sample() -> TemperatureReading? {
        guard let reader, !keys.isEmpty else { return nil }
        let reading = TemperatureReading(
            cpu: TemperatureSensors.hottest(keys.cpu.compactMap(reader.value)),
            gpu: TemperatureSensors.hottest(keys.gpu.compactMap(reader.value))
        )
        return reading.cpu == nil && reading.gpu == nil ? nil : reading
    }

    public static func cpuBrand() -> String {
        var size = 0
        guard sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0) == 0, size > 0 else { return "" }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0) == 0 else { return "" }
        return String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
    }
}
