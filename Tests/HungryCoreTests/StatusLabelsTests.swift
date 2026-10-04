import Testing
@testable import HungryCore

struct StatusLabelsTests {
    @Test func cpuAndMemoryUseLetterPrefix() {
        #expect(StatusLabels.text(for: .cpu, value: 23.4) == "C 23")
        #expect(StatusLabels.text(for: .memory, value: 45) == "R 45")
    }

    @Test func temperatureHasNoPrefix() {
        #expect(StatusLabels.text(for: .temperature, value: 68.2) == "68°")
    }

    @Test func threeDigitValueHasNoPercentSign() {
        #expect(StatusLabels.text(for: .cpu, value: 100) == "C 100")
    }

    @Test func singleDigitValueIsPaddedWithFigureSpace() {
        #expect(StatusLabels.text(for: .cpu, value: 5) == "C \u{2007}5")
        #expect(StatusLabels.text(for: .temperature, value: 7) == "\u{2007}7°")
    }

    @Test func missingValueShowsDashes() {
        #expect(StatusLabels.text(for: .cpu, value: nil) == "C --")
    }

    @Test func animationHasNoText() {
        #expect(StatusLabels.text(for: .animation, value: 50) == nil)
    }
}
