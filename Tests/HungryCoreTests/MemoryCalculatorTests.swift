import Testing
@testable import HungryCore

struct MemoryCalculatorTests {
    @Test func usedMemoryIsAppPlusWiredPlusCompressed() {
        let pages = MemoryPages(internalPages: 600, purgeablePages: 100, wiredPages: 200, compressedPages: 300)
        let usage = MemoryCalculator.usage(pages: pages, pageSize: 1_000, totalBytes: 2_000_000)
        #expect(usage.usedBytes == 1_000_000)
        #expect(usage.totalBytes == 2_000_000)
        #expect(usage.percent == 50)
    }

    @Test func purgeableLargerThanInternalCountsAsZeroAppMemory() {
        let pages = MemoryPages(internalPages: 10, purgeablePages: 50, wiredPages: 100, compressedPages: 0)
        let usage = MemoryCalculator.usage(pages: pages, pageSize: 10, totalBytes: 10_000)
        #expect(usage.usedBytes == 1_000)
        #expect(usage.percent == 10)
    }

    @Test func usedMemoryNeverExceedsTotal() {
        let pages = MemoryPages(internalPages: 5_000, purgeablePages: 0, wiredPages: 0, compressedPages: 0)
        let usage = MemoryCalculator.usage(pages: pages, pageSize: 16_384, totalBytes: 1_000)
        #expect(usage.usedBytes == 1_000)
        #expect(usage.percent == 100)
    }

    @Test func zeroTotalGivesZeroPercent() {
        let pages = MemoryPages(internalPages: 1, purgeablePages: 0, wiredPages: 1, compressedPages: 1)
        #expect(MemoryCalculator.usage(pages: pages, pageSize: 16_384, totalBytes: 0).percent == 0)
    }
}
