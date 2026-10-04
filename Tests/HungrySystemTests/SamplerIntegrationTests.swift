import Foundation
import Testing
import HungryCore
import HungrySystem

extension Tag {
    @Tag static var integration: Self
}

@Suite(.tags(.integration))
struct SamplerIntegrationTests {
    @Test func systemSamplerGivesValuesInRange() async throws {
        var sampler = SystemSampler()
        let first = sampler.sampleCPU()
        #expect(first == nil)
        try await Task.sleep(for: .milliseconds(300))
        let second = sampler.sampleCPU()
        let cpu = try #require(second)
        #expect((0...100).contains(cpu))
        let memory = try #require(sampler.sampleMemory())
        #expect((0...100).contains(memory.percent))
        #expect(memory.totalBytes > 0)
    }

    @Test func psRunnerReadsRootProcessesAndParentPids() throws {
        let output = try #require(PSRunner.run(timeout: ProcessSampler.psTimeout))
        let samples = PSParser.parse(output)
        #expect(samples.count > 50)
        #expect(samples.contains { $0.pid == 1 })
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let own = try #require(samples.first { $0.pid == ownPID })
        #expect(own.parentPid == getppid())
    }

    @Test func libprocFallbackReadsOwnProcessAndParentPid() throws {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let own = try #require(LibprocReader.samples().first { $0.pid == ownPID })
        #expect(own.parentPid == getppid())
    }

    @Test func processSamplerIsReadyOnSecondSample() async throws {
        var sampler = ProcessSampler()
        let first = sampler.sample(limit: 10)
        #expect(!first.isReady)
        try await Task.sleep(for: .milliseconds(500))
        let snapshot = sampler.sample(limit: 10)
        #expect(snapshot.isReady)
        #expect(!snapshot.isLimited)
        #expect(!snapshot.apps.isEmpty)
        #expect(snapshot.apps.count <= 10)
    }
}
