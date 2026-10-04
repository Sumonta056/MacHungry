import Testing
@testable import HungryCore

struct TopAppsLimitTests {
    @Test func defaultIsTen() {
        #expect(TopAppsLimit.default == .ten)
        #expect(TopAppsLimit.default.rawValue == 10)
    }

    @Test(arguments: [(10, TopAppsLimit.ten), (20, .twenty)] as [(Int?, TopAppsLimit)])
    func storedValidValueIsKept(stored: Int?, expected: TopAppsLimit) {
        #expect(TopAppsLimit(stored: stored) == expected)
    }

    @Test(arguments: [nil, 0, 15, -1] as [Int?])
    func storedInvalidValueGivesDefault(stored: Int?) {
        #expect(TopAppsLimit(stored: stored) == .default)
    }
}
