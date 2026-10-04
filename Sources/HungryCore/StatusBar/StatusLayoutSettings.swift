public struct StatusLayoutSettings: Equatable, Sendable {
    public static let `default` = StatusLayoutSettings(order: StatusSegment.allCases, hidden: [])

    public private(set) var order: [StatusSegment]
    public private(set) var hidden: Set<StatusSegment>
    public private(set) var unavailable: Set<StatusSegment> = []

    public init(order: [StatusSegment], hidden: Set<StatusSegment>) {
        var unique: [StatusSegment] = []
        for segment in order where !unique.contains(segment) {
            unique.append(segment)
        }
        unique += StatusSegment.allCases.filter { !unique.contains($0) }
        self.order = unique
        self.hidden = hidden
        showAllIfNothingVisible()
    }

    public init(storedOrder: [String], storedHidden: [String]) {
        self.init(
            order: storedOrder.compactMap(StatusSegment.init(rawValue:)),
            hidden: Set(storedHidden.compactMap(StatusSegment.init(rawValue:)))
        )
    }

    public var availableOrder: [StatusSegment] {
        order.filter { !unavailable.contains($0) }
    }

    public var visibleSegments: [StatusSegment] {
        order.filter(isVisible)
    }

    public var isDefaultLayout: Bool {
        order == Self.default.order && hidden.isEmpty
    }

    public func isVisible(_ segment: StatusSegment) -> Bool {
        !hidden.contains(segment) && !unavailable.contains(segment)
    }

    public func canHide(_ segment: StatusSegment) -> Bool {
        isVisible(segment) && visibleSegments.count > 1
    }

    public func canMoveLeft(_ segment: StatusSegment) -> Bool {
        neighbor(of: segment, offset: -1) != nil
    }

    public func canMoveRight(_ segment: StatusSegment) -> Bool {
        neighbor(of: segment, offset: 1) != nil
    }

    public func withUnavailable(_ segments: Set<StatusSegment>) -> StatusLayoutSettings {
        var copy = self
        copy.unavailable = segments
        copy.showAllIfNothingVisible()
        return copy
    }

    public func togglingVisibility(of segment: StatusSegment) -> StatusLayoutSettings {
        guard !unavailable.contains(segment) else { return self }
        var copy = self
        if isVisible(segment) {
            guard canHide(segment) else { return self }
            copy.hidden.insert(segment)
        } else {
            copy.hidden.remove(segment)
        }
        return copy
    }

    public func movingLeft(_ segment: StatusSegment) -> StatusLayoutSettings {
        swapping(segment, with: neighbor(of: segment, offset: -1))
    }

    public func movingRight(_ segment: StatusSegment) -> StatusLayoutSettings {
        swapping(segment, with: neighbor(of: segment, offset: 1))
    }

    private func neighbor(of segment: StatusSegment, offset: Int) -> StatusSegment? {
        let available = availableOrder
        guard let index = available.firstIndex(of: segment) else { return nil }
        let target = index + offset
        return available.indices.contains(target) ? available[target] : nil
    }

    private func swapping(_ segment: StatusSegment, with other: StatusSegment?) -> StatusLayoutSettings {
        guard let other, let from = order.firstIndex(of: segment), let to = order.firstIndex(of: other) else { return self }
        var copy = self
        copy.order.swapAt(from, to)
        return copy
    }

    private mutating func showAllIfNothingVisible() {
        if visibleSegments.isEmpty {
            hidden = []
        }
    }
}
