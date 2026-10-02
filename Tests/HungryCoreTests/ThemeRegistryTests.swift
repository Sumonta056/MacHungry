import Testing
@testable import HungryCore

struct ThemeRegistryTests {
    @Test func registryHasThreeThemesInPickerOrder() {
        #expect(ThemeRegistry.all.map(\.id) == ["cat", "pushup", "pullup"])
    }

    @Test(arguments: ["cat", "pushup", "pullup"])
    func findsThemeByID(id: String) {
        #expect(ThemeRegistry.theme(withID: id).id == id)
    }

    @Test(arguments: [nil, "", "dragon"] as [String?])
    func unknownIDFallsBackToCat(id: String?) {
        #expect(ThemeRegistry.theme(withID: id).id == "cat")
    }

    @Test func everyThemeHasValidFramesAndIntervals() {
        for theme in ThemeRegistry.all {
            #expect(theme.frameCount > 0)
            #expect(theme.frameNames.count == theme.frameCount)
            #expect(theme.frameNames.first == "frame-1")
            #expect(theme.minInterval < theme.maxInterval)
            #expect(theme.minInterval >= SpeedCurve.minimumTimerInterval)
        }
    }

    @Test func themeIDsAreUnique() {
        let ids = ThemeRegistry.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
