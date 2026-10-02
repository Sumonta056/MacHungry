import Testing
@testable import HungryCore

struct UsageFormatterTests {
    @Test(arguments: [(72.4, "72%"), (72.5, "73%"), (0.0, "0%"), (100.0, "100%")] as [(Double?, String)])
    func formatsPercent(value: Double?, expected: String) {
        #expect(UsageFormatter.percent(value) == expected)
    }

    @Test func missingOrInvalidValueShowsDashes() {
        #expect(UsageFormatter.percent(nil) == "--")
        #expect(UsageFormatter.percent(.nan) == "--")
    }

    @Test func tooltipNamesBothValues() {
        #expect(UsageFormatter.tooltip(cpu: 72, memory: nil) == "CPU 72% · RAM --")
    }

    @Test func memoryDetailShowsUsedAndTotalGigabytes() {
        #expect(UsageFormatter.memoryDetail(usedBytes: 10_522_669_875, totalBytes: 17_179_869_184) == "9.8 / 16 GB")
    }
}
