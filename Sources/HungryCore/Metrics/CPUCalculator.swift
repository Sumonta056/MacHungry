public enum CPUCalculator {
    public static func usagePercent(previous: [CoreTicks], current: [CoreTicks]) -> Double {
        guard previous.count == current.count, !current.isEmpty else { return 0 }
        var busy: UInt64 = 0
        var total: UInt64 = 0
        for (old, new) in zip(previous, current) {
            let coreBusy = delta(old.user, new.user) + delta(old.system, new.system) + delta(old.nice, new.nice)
            busy += coreBusy
            total += coreBusy + delta(old.idle, new.idle)
        }
        guard total > 0 else { return 0 }
        return Double(busy) / Double(total) * 100
    }

    private static func delta(_ old: UInt32, _ new: UInt32) -> UInt64 {
        UInt64(new &- old)
    }
}
