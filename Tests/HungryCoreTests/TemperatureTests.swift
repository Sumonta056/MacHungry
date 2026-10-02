import Testing
@testable import HungryCore

struct TemperatureTests {
    @Test(arguments: [
        ("Apple M1", ChipFamily.m1),
        ("Apple M1 Pro", .m1),
        ("Apple M2 Max", .m2),
        ("Apple M3", .m3),
        ("Apple M4 Pro", .m4),
    ] as [(String, ChipFamily)])
    func detectsAppleSiliconFamily(brand: String, expected: ChipFamily) {
        #expect(ChipFamily.detect(brand: brand) == expected)
    }

    @Test(arguments: ["Intel(R) Core(TM) i7-9750H CPU @ 2.60GHz", "", "Apple M", "Apple M10", "Apple M9 Ultra"])
    func unknownChipHasNoFamily(brand: String) {
        #expect(ChipFamily.detect(brand: brand) == nil)
    }

    @Test(arguments: ChipFamily.allCases)
    func everyFamilyHasValidUniqueKeys(family: ChipFamily) {
        let keys = TemperatureSensors.keys(for: family)
        #expect(!keys.cpu.isEmpty)
        #expect(!keys.gpu.isEmpty)
        for key in keys.cpu + keys.gpu {
            #expect(key.utf8.count == 4)
            #expect(key.hasPrefix("T"))
        }
        #expect(Set(keys.cpu).count == keys.cpu.count)
        #expect(Set(keys.gpu).count == keys.gpu.count)
    }

    @Test func m1TableMatchesVerifiedM1ProKeys() {
        let keys = TemperatureSensors.keys(for: .m1)
        #expect(Set(["Tp01", "Tp05", "Tp09", "Tp0D", "Tp0H", "Tp0L", "Tp0P", "Tp0T", "Tp0X", "Tp0b"]).isSubset(of: Set(keys.cpu)))
        #expect(Set(["Tg05", "Tg0D"]).isSubset(of: Set(keys.gpu)))
    }

    @Test func hottestIgnoresInvalidValues() {
        #expect(TemperatureSensors.hottest([66.8, 73.6, 0, -5, 200, .nan, .infinity]) == 73.6)
    }

    @Test func hottestOfNothingIsNil() {
        #expect(TemperatureSensors.hottest([]) == nil)
        #expect(TemperatureSensors.hottest([0, 151]) == nil)
    }

    @Test func firstReadingIsUsedAsIs() {
        let reading = TemperatureReading(cpu: 60, gpu: 50)
        #expect(TemperatureSensors.smooth(previous: nil, new: reading) == reading)
    }

    @Test func smoothingMovesThirtyPercentTowardNewReading() throws {
        let smoothed = try #require(TemperatureSensors.smooth(previous: TemperatureReading(cpu: 60, gpu: 50), new: TemperatureReading(cpu: 70, gpu: 60)))
        #expect(abs(try #require(smoothed.cpu) - 63) < 0.000_001)
        #expect(abs(try #require(smoothed.gpu) - 53) < 0.000_001)
    }

    @Test func missingReadingKeepsPreviousValues() {
        let previous = TemperatureReading(cpu: 61, gpu: 52)
        #expect(TemperatureSensors.smooth(previous: previous, new: nil) == previous)
        #expect(TemperatureSensors.smooth(previous: previous, new: TemperatureReading(cpu: nil, gpu: 62))?.cpu == 61)
    }

    @Test func formatsMenuBarTemperature() {
        #expect(UsageFormatter.temperature(68.4) == "68°")
        #expect(UsageFormatter.temperature(nil) == "--")
        #expect(UsageFormatter.temperature(.nan) == "--")
    }

    @Test func formatsPopoverDetail() {
        #expect(UsageFormatter.temperatureDetail(TemperatureReading(cpu: 68.4, gpu: 64.5)) == "CPU 68°C  GPU 65°C")
        #expect(UsageFormatter.temperatureDetail(TemperatureReading(cpu: 70, gpu: nil)) == "CPU 70°C")
        #expect(UsageFormatter.temperatureDetail(TemperatureReading(cpu: nil, gpu: nil)) == "")
    }

    @Test func tooltipAddsTemperatureOnlyWhenKnown() {
        #expect(UsageFormatter.tooltip(cpu: 72, memory: 61, temperature: 68.4) == "CPU 72% · RAM 61% · 68°C")
        #expect(UsageFormatter.tooltip(cpu: 72, memory: 61) == "CPU 72% · RAM 61%")
    }
}
