import Testing
@testable import HungryCore

struct RankStabilizerTests {
    private func app(_ name: String, _ percent: Double) -> AppUsage {
        AppUsage(identity: AppIdentity(name: name, bundlePath: nil), percent: percent)
    }

    @Test func firstListKeepsSortedOrder() {
        let current = [app("a", 30), app("b", 20)]
        #expect(RankStabilizer.stabilize(previousOrder: [], current: current, threshold: 1).map(\.id) == ["a", "b"])
    }

    @Test func smallDifferenceKeepsPreviousOrder() {
        let current = [app("b", 20.5), app("a", 20)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["a", "b"])
    }

    @Test func largeDifferenceChangesOrder() {
        let current = [app("b", 25), app("a", 20)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["b", "a"])
    }

    @Test func newcomerMovesUpOnlyPastClearlyLowerRows() {
        let current = [app("c", 50), app("a", 49.5), app("b", 10)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["a", "c", "b"])
    }

    @Test func droppedAppsDisappear() {
        let current = [app("b", 5)]
        #expect(RankStabilizer.stabilize(previousOrder: ["a", "b"], current: current, threshold: 1).map(\.id) == ["b"])
    }
}
