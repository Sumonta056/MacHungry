import Testing
@testable import HungryCore

struct SpeedCurveTests {
    @Test(arguments: [(0.0, 0.20), (50.0, 0.115), (100.0, 0.03), (-20.0, 0.20), (250.0, 0.03), (Double.nan, 0.20)])
    func catIntervalFollowsCPU(cpu: Double, expected: Double) {
        #expect(abs(CatTheme().frameInterval(forCPU: cpu) - expected) < 0.000_001)
    }

    @Test func intervalNeverGoesBelowMinimumTimer() {
        #expect(SpeedCurve.interval(forCPU: 100, maxInterval: 0.1, minInterval: 0.001) == SpeedCurve.minimumTimerInterval)
    }

    @Test func smoothingMovesThirtyPercentTowardNewValue() {
        #expect(abs(SpeedCurve.smooth(previous: 0, new: 100) - 30) < 0.000_001)
        #expect(abs(SpeedCurve.smooth(previous: 50, new: 50) - 50) < 0.000_001)
    }

    @Test func smoothingIgnoresInvalidInput() {
        #expect(SpeedCurve.smooth(previous: 10, new: .infinity) == 7)
    }

    @Test func timerIsReplacedOnlyAboveFiveMilliseconds() {
        #expect(!SpeedCurve.shouldReplaceTimer(current: 0.100, new: 0.104))
        #expect(SpeedCurve.shouldReplaceTimer(current: 0.100, new: 0.110))
    }
}
