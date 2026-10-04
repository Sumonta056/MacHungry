import Darwin
import HungryCore

public struct SystemSampler {
    private let host = mach_host_self()
    private let totalMemory = Self.readTotalMemory()
    private let pageSize = UInt64(getpagesize())
    private var previousTicks: [CoreTicks]?

    public init() {}

    public mutating func sampleCPU() -> Double? {
        guard let ticks = readCoreTicks() else { return nil }
        defer { previousTicks = ticks }
        guard let previousTicks else { return nil }
        return CPUCalculator.usagePercent(previous: previousTicks, current: ticks)
    }

    public func sampleMemory() -> MemoryUsage? {
        guard totalMemory > 0, let pages = readMemoryPages() else { return nil }
        return MemoryCalculator.usage(pages: pages, pageSize: pageSize, totalBytes: totalMemory)
    }

    private func readCoreTicks() -> [CoreTicks]? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        let result = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            let size = vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)), size)
        }
        let stateCount = Int(CPU_STATE_MAX)
        return (0..<Int(cpuCount)).map { core in
            let base = core * stateCount
            return CoreTicks(
                user: UInt32(bitPattern: info[base + Int(CPU_STATE_USER)]),
                system: UInt32(bitPattern: info[base + Int(CPU_STATE_SYSTEM)]),
                nice: UInt32(bitPattern: info[base + Int(CPU_STATE_NICE)]),
                idle: UInt32(bitPattern: info[base + Int(CPU_STATE_IDLE)])
            )
        }
    }

    private func readMemoryPages() -> MemoryPages? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return MemoryPages(
            internalPages: UInt64(stats.internal_page_count),
            purgeablePages: UInt64(stats.purgeable_count),
            wiredPages: UInt64(stats.wire_count),
            compressedPages: UInt64(stats.compressor_page_count)
        )
    }

    private static func readTotalMemory() -> UInt64 {
        var size: UInt64 = 0
        var length = MemoryLayout<UInt64>.size
        return sysctlbyname("hw.memsize", &size, &length, nil, 0) == 0 ? size : 0
    }
}
