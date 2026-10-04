import Testing
@testable import HungryCore

struct StatusLayoutSettingsTests {
    @Test func defaultShowsAllSegmentsInDefaultOrder() {
        let settings = StatusLayoutSettings.default
        #expect(settings.order == [.animation, .cpu, .memory, .temperature])
        #expect(settings.visibleSegments == [.animation, .cpu, .memory, .temperature])
    }

    @Test func togglingHidesAndShowsSegment() {
        let hidden = StatusLayoutSettings.default.togglingVisibility(of: .cpu)
        #expect(!hidden.isVisible(.cpu))
        #expect(hidden.visibleSegments == [.animation, .memory, .temperature])
        #expect(hidden.togglingVisibility(of: .cpu).isVisible(.cpu))
    }

    @Test func lastVisibleSegmentCannotBeHidden() {
        let settings = StatusLayoutSettings(order: StatusSegment.allCases, hidden: [.animation, .cpu, .temperature])
        #expect(!settings.canHide(.memory))
        #expect(settings.togglingVisibility(of: .memory) == settings)
    }

    @Test func movingSwapsNeighbors() {
        let settings = StatusLayoutSettings.default
        #expect(settings.movingLeft(.cpu).order == [.cpu, .animation, .memory, .temperature])
        #expect(settings.movingRight(.cpu).order == [.animation, .memory, .cpu, .temperature])
    }

    @Test func endsCannotMovePastEdge() {
        let settings = StatusLayoutSettings.default
        #expect(!settings.canMoveLeft(.animation))
        #expect(!settings.canMoveRight(.temperature))
        #expect(settings.movingLeft(.animation) == settings)
        #expect(settings.movingRight(.temperature) == settings)
    }

    @Test func hiddenSegmentKeepsPosition() {
        let settings = StatusLayoutSettings.default
            .togglingVisibility(of: .memory)
            .movingLeft(.temperature)
            .togglingVisibility(of: .memory)
        #expect(settings.order == [.animation, .cpu, .temperature, .memory])
        #expect(settings.visibleSegments == [.animation, .cpu, .temperature, .memory])
    }

    @Test func storedDataDropsUnknownAndDuplicateNames() {
        let settings = StatusLayoutSettings(storedOrder: ["memory", "gpu", "memory", "cpu"], storedHidden: ["cpu", "fan"])
        #expect(settings.order == [.memory, .cpu, .animation, .temperature])
        #expect(settings.hidden == [.cpu])
    }

    @Test func storedDataWithAllHiddenShowsAll() {
        let settings = StatusLayoutSettings(storedOrder: [], storedHidden: StatusSegment.allCases.map(\.rawValue))
        #expect(settings == .default)
    }

    @Test func storedDataRoundTrips() {
        let settings = StatusLayoutSettings.default.movingRight(.animation).togglingVisibility(of: .temperature)
        let restored = StatusLayoutSettings(storedOrder: settings.order.map(\.rawValue), storedHidden: settings.hidden.map(\.rawValue))
        #expect(restored == settings)
    }

    @Test func unavailableSegmentIsNotVisible() {
        let settings = StatusLayoutSettings.default.withUnavailable([.temperature])
        #expect(!settings.isVisible(.temperature))
        #expect(settings.availableOrder == [.animation, .cpu, .memory])
        #expect(settings.visibleSegments == [.animation, .cpu, .memory])
    }

    @Test func lastAvailableVisibleSegmentCannotBeHidden() {
        let settings = StatusLayoutSettings(order: StatusSegment.allCases, hidden: [.animation, .cpu])
            .withUnavailable([.temperature])
        #expect(!settings.canHide(.memory))
        #expect(settings.togglingVisibility(of: .memory) == settings)
    }

    @Test func onlyUnavailableSegmentVisibleShowsAllAvailable() {
        let settings = StatusLayoutSettings(order: StatusSegment.allCases, hidden: [.animation, .cpu, .memory])
            .withUnavailable([.temperature])
        #expect(settings.visibleSegments == [.animation, .cpu, .memory])
    }

    @Test func movingSkipsUnavailableSegment() {
        let settings = StatusLayoutSettings(order: [.cpu, .temperature, .memory, .animation], hidden: [])
            .withUnavailable([.temperature])
        #expect(settings.canMoveRight(.cpu))
        #expect(settings.movingRight(.cpu).availableOrder == [.memory, .cpu, .animation])
        #expect(!settings.canMoveLeft(.cpu))
    }

    @Test func defaultLayoutIgnoresUnavailable() {
        #expect(StatusLayoutSettings.default.withUnavailable([.temperature]).isDefaultLayout)
        #expect(!StatusLayoutSettings.default.movingLeft(.cpu).isDefaultLayout)
        #expect(!StatusLayoutSettings.default.togglingVisibility(of: .cpu).isDefaultLayout)
    }
}
