import HungryCore

struct StatusValues {
    var cpu: Double?
    var memory: Double?
    var temperature: Double?

    func value(for segment: StatusSegment) -> Double? {
        switch segment {
        case .animation: nil
        case .cpu: cpu
        case .memory: memory
        case .temperature: temperature
        }
    }
}
