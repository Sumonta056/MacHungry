import Darwin
import HungryCore

public enum LibprocReader {
    private static let pathBufferSize = Int(MAXPATHLEN) * 4

    public static func samples() -> [ProcessSample] {
        let estimated = proc_listallpids(nil, 0)
        guard estimated > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimated) + 64)
        let filled = proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.stride))
        guard filled > 0 else { return [] }
        let scale = timebaseScale()
        var pathBuffer = [CChar](repeating: 0, count: pathBufferSize)
        var result: [ProcessSample] = []
        result.reserveCapacity(Int(filled))
        for pid in pids.prefix(Int(filled)) where pid > 0 {
            guard let cpuTicks = cpuTicks(of: pid) else { continue }
            let length = proc_pidpath(pid, &pathBuffer, UInt32(pathBufferSize))
            guard length > 0 else { continue }
            let path = String(decoding: pathBuffer.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            result.append(ProcessSample(pid: pid, parentPid: parentPid(of: pid), cpuSeconds: Double(cpuTicks) * scale / 1_000_000_000, path: path))
        }
        return result
    }

    private static func cpuTicks(of pid: pid_t) -> UInt64? {
        var info = rusage_info_v2()
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V2, $0)
            }
        }
        return status == 0 ? info.ri_user_time + info.ri_system_time : nil
    }

    private static func parentPid(of pid: pid_t) -> Int32 {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.stride)
        let read = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size)
        return read == size ? Int32(bitPattern: info.pbi_ppid) : 0
    }

    private static func timebaseScale() -> Double {
        var timebase = mach_timebase_info_data_t()
        guard mach_timebase_info(&timebase) == KERN_SUCCESS, timebase.denom > 0 else { return 1 }
        return Double(timebase.numer) / Double(timebase.denom)
    }
}
