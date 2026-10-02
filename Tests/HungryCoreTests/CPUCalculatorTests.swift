import Testing
@testable import HungryCore

struct CPUCalculatorTests {
    @Test func idleMachineIsZero() {
        let previous = [CoreTicks(user: 10, system: 10, nice: 0, idle: 100)]
        let current = [CoreTicks(user: 10, system: 10, nice: 0, idle: 200)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 0)
    }

    @Test func fullLoadIsHundred() {
        let previous = [CoreTicks(user: 0, system: 0, nice: 0, idle: 50)]
        let current = [CoreTicks(user: 60, system: 30, nice: 10, idle: 50)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 100)
    }

    @Test func mixedCoresAverageBusyShare() {
        let previous = [CoreTicks(user: 0, system: 0, nice: 0, idle: 0), CoreTicks(user: 0, system: 0, nice: 0, idle: 0)]
        let current = [CoreTicks(user: 100, system: 0, nice: 0, idle: 0), CoreTicks(user: 0, system: 0, nice: 0, idle: 100)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 50)
    }

    @Test func noElapsedTicksIsZero() {
        let ticks = [CoreTicks(user: 5, system: 5, nice: 5, idle: 5)]
        #expect(CPUCalculator.usagePercent(previous: ticks, current: ticks) == 0)
    }

    @Test func coreCountChangeIsZero() {
        let previous = [CoreTicks(user: 0, system: 0, nice: 0, idle: 0)]
        let current = [CoreTicks(user: 9, system: 0, nice: 0, idle: 1), CoreTicks(user: 9, system: 0, nice: 0, idle: 1)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 0)
    }

    @Test func counterWrapAroundStaysPositive() {
        let previous = [CoreTicks(user: UInt32.max - 9, system: 0, nice: 0, idle: 0)]
        let current = [CoreTicks(user: 10, system: 0, nice: 0, idle: 20)]
        #expect(CPUCalculator.usagePercent(previous: previous, current: current) == 50)
    }
}
