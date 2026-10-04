import Foundation
import HungryCore

public struct ProcessSnapshot: Sendable {
    public var apps: [AppUsage]
    public var isReady: Bool
    public var isLimited: Bool
}

public struct ProcessSampler {
    public static let psTimeout: TimeInterval = 0.8

    private var tracker = ProcessCPUTracker(coreCount: ProcessInfo.processInfo.activeProcessorCount)

    public init() {}

    public mutating func sample(limit: Int) -> ProcessSnapshot {
        let wasReady = tracker.hasBaseline
        let output = PSRunner.run(timeout: Self.psTimeout)
        let now = ProcessInfo.processInfo.systemUptime
        let samples = output.map(PSParser.parse) ?? LibprocReader.samples()
        let usages = tracker.update(samples: samples, at: now)
        let tree = ProcessTree(samples: samples)
        return ProcessSnapshot(
            apps: AppGrouper.topApps(tree.ownerUsages(usages), limit: limit),
            isReady: wasReady,
            isLimited: output == nil
        )
    }

    public mutating func reset() {
        tracker.reset()
    }
}
