import Observation
import HungryCore

@MainActor
@Observable
final class StatsStore {
    var cpuPercent: Double?
    var memory: MemoryUsage?
    var temperature: TemperatureReading?
    var topApps: [AppUsage] = []
    var hasTopSample = false
    var isLimited = false
}
