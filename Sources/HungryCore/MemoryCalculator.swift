public struct MemoryPages: Equatable, Sendable {
    public var internalPages: UInt64
    public var purgeablePages: UInt64
    public var wiredPages: UInt64
    public var compressedPages: UInt64

    public init(internalPages: UInt64, purgeablePages: UInt64, wiredPages: UInt64, compressedPages: UInt64) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressedPages = compressedPages
    }
}

public struct MemoryUsage: Equatable, Sendable {
    public var usedBytes: UInt64
    public var totalBytes: UInt64
    public var percent: Double

    public init(usedBytes: UInt64, totalBytes: UInt64, percent: Double) {
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.percent = percent
    }
}

public enum MemoryCalculator {
    public static func usage(pages: MemoryPages, pageSize: UInt64, totalBytes: UInt64) -> MemoryUsage {
        let appPages = pages.internalPages > pages.purgeablePages ? pages.internalPages - pages.purgeablePages : 0
        let usedBytes = min((appPages + pages.wiredPages + pages.compressedPages) * pageSize, totalBytes)
        let percent = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
        return MemoryUsage(usedBytes: usedBytes, totalBytes: totalBytes, percent: percent)
    }
}
