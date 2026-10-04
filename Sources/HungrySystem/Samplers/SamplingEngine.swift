import HungryCore

public struct SystemSnapshot: Sendable {
    public var cpuPercent: Double?
    public var memory: MemoryUsage?
    public var temperature: TemperatureReading?
}

public actor SamplingEngine {
    public static let temperatureEvery = 2

    private var system = SystemSampler()
    private var processes = ProcessSampler()
    private let temperature: TemperatureSampler
    private var temperatureTick = 0
    private var lastTemperature: TemperatureReading?

    public nonisolated let isTemperatureAvailable: Bool

    public init() {
        let sampler = TemperatureSampler()
        temperature = sampler
        isTemperatureAvailable = sampler.isAvailable
    }

    public func sampleSystem(includeTemperature: Bool = true) -> SystemSnapshot {
        if includeTemperature {
            if temperatureTick % Self.temperatureEvery == 0 {
                lastTemperature = TemperatureSensors.smooth(previous: lastTemperature, new: temperature.sample())
            }
            temperatureTick += 1
        } else {
            temperatureTick = 0
            lastTemperature = nil
        }
        return SystemSnapshot(cpuPercent: system.sampleCPU(), memory: system.sampleMemory(), temperature: lastTemperature)
    }

    public func sampleProcesses(limit: Int) -> ProcessSnapshot {
        processes.sample(limit: limit)
    }

    public func resetProcesses() {
        processes.reset()
    }
}
