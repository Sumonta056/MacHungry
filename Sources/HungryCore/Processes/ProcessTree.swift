public struct ProcessTree: Sendable {
    public static let maxDepth = 64
    public static let shellNames: Set<String> = ["sh", "bash", "zsh", "fish", "dash", "ksh", "tcsh", "csh", "login"]

    private static let launchdPid: Int32 = 1

    private let parents: [Int32: Int32]
    private let paths: [Int32: String]
    private let shellPids: Set<Int32>

    public init(samples: [ProcessSample]) {
        var parents: [Int32: Int32] = [:]
        var paths: [Int32: String] = [:]
        var shellPids: Set<Int32> = []
        parents.reserveCapacity(samples.count)
        paths.reserveCapacity(samples.count)
        for sample in samples {
            parents[sample.pid] = sample.parentPid
            paths[sample.pid] = sample.path
            if Self.isShellPath(sample.path) {
                shellPids.insert(sample.pid)
            }
        }
        self.parents = parents
        self.paths = paths
        self.shellPids = shellPids
    }

    public func ownerPath(of pid: Int32) -> String? {
        guard let ownPath = paths[pid] else { return nil }
        guard pid != Self.launchdPid, let chain = chainUp(from: pid) else { return ownPath }
        let topDown = Array(chain.reversed())
        if let firstShell = topDown.firstIndex(where: isShell),
           let owner = topDown[(firstShell + 1)...].first(where: { !isShell($0) }) {
            return paths[owner] ?? ownPath
        }
        return topDown.first.flatMap { paths[$0] } ?? ownPath
    }

    public func ownerUsages(_ usages: [ProcessUsage]) -> [ProcessUsage] {
        usages.map { usage in
            ProcessUsage(pid: usage.pid, path: ownerPath(of: usage.pid) ?? usage.path, percent: usage.percent)
        }
    }

    private func chainUp(from pid: Int32) -> [Int32]? {
        var chain = [pid]
        var visited: Set<Int32> = [pid]
        var current = pid
        while let parent = parents[current], parent > Self.launchdPid, paths[parent] != nil {
            guard !visited.contains(parent), chain.count <= Self.maxDepth else { return nil }
            chain.append(parent)
            visited.insert(parent)
            current = parent
        }
        return chain
    }

    private func isShell(_ pid: Int32) -> Bool {
        shellPids.contains(pid)
    }

    private static func isShellPath(_ path: String) -> Bool {
        let name = path.split(separator: "/").last.map(String.init) ?? path
        let bare = name.hasPrefix("-") ? String(name.dropFirst()) : name
        return shellNames.contains(bare)
    }
}
