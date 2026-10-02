import Testing
@testable import HungryCore

struct ProcessCPUTrackerTests {
    @Test func firstSampleOnlyCreatesBaseline() {
        var tracker = ProcessCPUTracker()
        #expect(!tracker.hasBaseline)
        let usages = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 10, path: "/bin/a")], at: 100)
        #expect(usages.isEmpty)
        #expect(tracker.hasBaseline)
    }

    @Test func percentIsCPUSecondsOverWallSeconds() throws {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 10, path: "/bin/a")], at: 100)
        let usages = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 13, path: "/bin/a")], at: 102)
        let usage = try #require(usages.first)
        #expect(usage.percent == 150)
        #expect(usage.path == "/bin/a")
    }

    @Test func newPidShowsFromNextSample() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 0)
        let usages = tracker.update(samples: [
            ProcessSample(pid: 1, cpuSeconds: 1, path: "/bin/a"),
            ProcessSample(pid: 2, cpuSeconds: 50, path: "/bin/b"),
        ], at: 1)
        #expect(usages.map(\.pid) == [1])
    }

    @Test func pidReuseShowsZeroForThatSample() throws {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 7, cpuSeconds: 500, path: "/bin/old")], at: 0)
        let usages = tracker.update(samples: [ProcessSample(pid: 7, cpuSeconds: 2, path: "/bin/new")], at: 1)
        #expect(try #require(usages.first).percent == 0)
        let next = tracker.update(samples: [ProcessSample(pid: 7, cpuSeconds: 3, path: "/bin/new")], at: 2)
        #expect(try #require(next.first).percent == 100)
    }

    @Test func stoppedPidsAreRemoved() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [
            ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a"),
            ProcessSample(pid: 2, cpuSeconds: 0, path: "/bin/b"),
        ], at: 0)
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 1)
        #expect(tracker.trackedCount == 1)
    }

    @Test func nonPositiveElapsedTimeGivesNoUsage() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 5)
        #expect(tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 1, path: "/bin/a")], at: 5).isEmpty)
    }

    @Test func resetClearsBaseline() {
        var tracker = ProcessCPUTracker()
        _ = tracker.update(samples: [ProcessSample(pid: 1, cpuSeconds: 0, path: "/bin/a")], at: 0)
        tracker.reset()
        #expect(!tracker.hasBaseline)
        #expect(tracker.trackedCount == 0)
    }
}
