import Testing
import HungryCore
@testable import HungrySystem

@Suite(.tags(.integration))
struct TemperatureIntegrationTests {
    @Test func smcParamMatchesTheCLayout() {
        #expect(MemoryLayout<SMCParam>.stride == SMCReader.expectedParamSize)
    }

    @Test func readsPlausibleTemperatureOnSupportedMacs() throws {
        let sampler = TemperatureSampler()
        guard ChipFamily.detect(brand: TemperatureSampler.cpuBrand()) != nil else { return }
        #expect(sampler.isAvailable)
        let reading = try #require(sampler.sample())
        let cpu = try #require(reading.cpu)
        #expect((15...120).contains(cpu))
    }

    @Test func unknownChipGivesNoTemperature() {
        let sampler = TemperatureSampler(brand: "Intel(R) Core(TM) i7")
        #expect(!sampler.isAvailable)
        #expect(sampler.sample() == nil)
    }

    @Test func engineSkipsTemperatureWhenExcluded() async {
        let engine = SamplingEngine()
        #expect(await engine.sampleSystem(includeTemperature: false).temperature == nil)
    }
}
