import Foundation
import HungryCore
import HungrySystem

@MainActor
final class StatsMonitor {
    static let rankThreshold = 1.0

    private let engine = SamplingEngine()
    private let store: StatsStore
    private var systemTask: Task<Void, Never>?
    private var processTask: Task<Void, Never>?
    private var previousOrder: [String] = []

    var onSystemSample: ((SystemSnapshot) -> Void)?
    var includesTemperature = true
    var topLimit: TopAppsLimit

    var isTemperatureAvailable: Bool {
        engine.isTemperatureAvailable
    }

    init(store: StatsStore, topLimit: TopAppsLimit) {
        self.store = store
        self.topLimit = topLimit
    }

    func start() {
        guard systemTask == nil else { return }
        systemTask = Task {
            while !Task.isCancelled {
                await refreshSystem()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func startProcessSampling() {
        guard processTask == nil else { return }
        previousOrder = []
        store.topApps = []
        store.hasTopSample = false
        processTask = Task {
            await engine.resetProcesses()
            var delay: Duration = .milliseconds(500)
            while !Task.isCancelled {
                await refreshProcesses()
                try? await Task.sleep(for: delay)
                delay = .seconds(1)
            }
        }
    }

    func stopProcessSampling() {
        processTask?.cancel()
        processTask = nil
        previousOrder = []
        store.topApps = []
        store.hasTopSample = false
        Task { await engine.resetProcesses() }
    }

    private func refreshSystem() async {
        let snapshot = await engine.sampleSystem(includeTemperature: includesTemperature)
        store.cpuPercent = snapshot.cpuPercent
        store.memory = snapshot.memory
        store.temperature = snapshot.temperature
        onSystemSample?(snapshot)
    }

    private func refreshProcesses() async {
        let snapshot = await engine.sampleProcesses(limit: topLimit.rawValue)
        guard !Task.isCancelled else { return }
        store.isLimited = snapshot.isLimited
        guard snapshot.isReady else { return }
        let ordered = RankStabilizer.stabilize(previousOrder: previousOrder, current: snapshot.apps, threshold: Self.rankThreshold)
        previousOrder = ordered.map(\.id)
        store.topApps = ordered
        store.hasTopSample = true
    }
}
