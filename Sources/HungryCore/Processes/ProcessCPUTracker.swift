public struct ProcessUsage: Equatable, Sendable {
    public var pid: Int32
    public var path: String
    public var percent: Double

    public init(pid: Int32, path: String, percent: Double) {
        self.pid = pid
        self.path = path
        self.percent = percent
    }
}

public struct ProcessCPUTracker: Sendable {
    private var lastCPUSeconds: [Int32: Double] = [:]
    private var lastTime: Double?

    public init() {}

    public var hasBaseline: Bool { lastTime != nil }
    public var trackedCount: Int { lastCPUSeconds.count }

    public mutating func update(samples: [ProcessSample], at time: Double) -> [ProcessUsage] {
        let elapsed = lastTime.map { time - $0 } ?? 0
        var next: [Int32: Double] = [:]
        next.reserveCapacity(samples.count)
        var usages: [ProcessUsage] = []
        usages.reserveCapacity(samples.count)
        for sample in samples {
            next[sample.pid] = sample.cpuSeconds
            guard elapsed > 0, let previous = lastCPUSeconds[sample.pid] else { continue }
            let used = sample.cpuSeconds - previous
            let percent = used >= 0 ? used / elapsed * 100 : 0
            usages.append(ProcessUsage(pid: sample.pid, path: sample.path, percent: percent))
        }
        lastCPUSeconds = next
        lastTime = time
        return usages
    }

    public mutating func reset() {
        lastCPUSeconds.removeAll()
        lastTime = nil
    }
}
