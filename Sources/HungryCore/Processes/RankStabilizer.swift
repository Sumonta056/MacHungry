public enum RankStabilizer {
    public static func stabilize(previousOrder: [String], current: [AppUsage], threshold: Double) -> [AppUsage] {
        let previousRank = Dictionary(previousOrder.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let known = current
            .filter { previousRank[$0.id] != nil }
            .sorted { (previousRank[$0.id] ?? 0) < (previousRank[$1.id] ?? 0) }
        let newcomers = current.filter { previousRank[$0.id] == nil }
        var result: [AppUsage] = []
        result.reserveCapacity(current.count)
        for item in known + newcomers {
            var index = result.count
            while index > 0, item.percent - result[index - 1].percent > threshold {
                index -= 1
            }
            result.insert(item, at: index)
        }
        return result
    }
}
